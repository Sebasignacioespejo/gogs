// Copyright 2014 The Gogs Authors. All rights reserved.
// Use of this source code is governed by a MIT-style
// license that can be found in the LICENSE file.

package repo

import (
	"net/http"
	"path"
	"strings"
	"time"

	"github.com/unknwon/com"
	log "unknwon.dev/clog/v2"

	"github.com/gogs/git-module"

	"gogs.io/gogs/internal/conf"
	"gogs.io/gogs/internal/context"
	"gogs.io/gogs/internal/database"
	"gogs.io/gogs/internal/form"
	"gogs.io/gogs/internal/gitutil"
)

const (
	tmplRepoPullsFork    = "repo/pulls/fork"
	tmplRepoPullsCompare = "repo/pulls/compare"
	tmplRepoPullsCommits = "repo/pulls/commits"
	tmplRepoPullsFiles   = "repo/pulls/files"

	PullRequestTemplateKey      = "PullRequestTemplate"
	PullRequestTitleTemplateKey = "PullRequestTitleTemplate"
)

var (
	PullRequestTemplateCandidates = []string{
		"PULL_REQUEST.md",
		".gogs/PULL_REQUEST.md",
		".github/PULL_REQUEST.md",
	}

	PullRequestTitleTemplateCandidates = []string{
		"PULL_REQUEST_TITLE.md",
		".gogs/PULL_REQUEST_TITLE.md",
		".github/PULL_REQUEST_TITLE.md",
	}
)

func parseBaseRepository(c *context.Context) *database.Repository {
	baseRepo, err := database.GetRepositoryByID(c.ParamsInt64(":repoid"))
	if err != nil {
		c.NotFoundOrError(err, "get repository by ID")
		return nil
	}

	if !baseRepo.CanBeForked() || !baseRepo.HasAccess(c.User.ID) {
		c.NotFound()
		return nil
	}

	c.Data["repo_name"] = baseRepo.Name
	c.Data["description"] = baseRepo.Description
	c.Data["IsPrivate"] = baseRepo.IsPrivate
	c.Data["IsUnlisted"] = baseRepo.IsUnlisted

	if err = baseRepo.GetOwner(); err != nil {
		c.Error(err, "get owner")
		return nil
	}
	c.Data["ForkFrom"] = baseRepo.Owner.Name + "/" + baseRepo.Name

	orgs, err := database.Handle.Organizations().List(
		c.Req.Context(),
		database.ListOrgsOptions{
			MemberID:              c.User.ID,
			IncludePrivateMembers: true,
		},
	)
	if err != nil {
		c.Error(err, "list organizations")
		return nil
	}
	c.Data["Orgs"] = orgs

	return baseRepo
}

func Fork(c *context.Context) {
	c.Data["Title"] = c.Tr("new_fork")

	parseBaseRepository(c)
	if c.Written() {
		return
	}

	c.Data["ContextUser"] = c.User
	c.Success(tmplRepoPullsFork)
}

func ForkPost(c *context.Context, f form.CreateRepo) {
	c.Data["Title"] = c.Tr("new_fork")

	baseRepo := parseBaseRepository(c)
	if c.Written() {
		return
	}

	ctxUser := checkContextUser(c, f.UserID)
	if c.Written() {
		return
	}
	c.Data["ContextUser"] = ctxUser

	if c.HasError() {
		c.Success(tmplRepoPullsFork)
		return
	}

	repo, has, err := database.HasForkedRepo(ctxUser.ID, baseRepo.ID)
	if err != nil {
		c.Error(err, "check forked repository")
		return
	} else if has {
		c.Redirect(repo.Link())
		return
	}

	// Check ownership of organization.
	if ctxUser.IsOrganization() && !ctxUser.IsOwnedBy(c.User.ID) {
		c.Status(http.StatusForbidden)
		return
	}

	// Cannot fork to same owner
	if ctxUser.ID == baseRepo.OwnerID {
		c.RenderWithErr(c.Tr("repo.settings.cannot_fork_to_same_owner"), tmplRepoPullsFork, &f)
		return
	}

	repo, err = database.ForkRepository(c.User, ctxUser, baseRepo, f.RepoName, f.Description)
	if err != nil {
		c.Data["Err_RepoName"] = true
		switch {
		case database.IsErrReachLimitOfRepo(err):
			c.RenderWithErr(c.Tr("repo.form.reach_limit_of_creation", err.(database.ErrReachLimitOfRepo).Limit), tmplRepoPullsFork, &f)
		case database.IsErrRepoAlreadyExist(err):
			c.RenderWithErr(c.Tr("repo.settings.new_owner_has_same_repo"), tmplRepoPullsFork, &f)
		case database.IsErrNameNotAllowed(err):
			c.RenderWithErr(c.Tr("repo.form.name_not_allowed", err.(database.ErrNameNotAllowed).Value()), tmplRepoPullsFork, &f)
		default:
			c.Error(err, "fork repository")
		}
		return
	}

	log.Trace("Repository forked from '%s' -> '%s'", baseRepo.FullName(), repo.FullName())
	c.Redirect(repo.Link())
}

func checkPullInfo(c *context.Context) *database.Issue {
	issue, err := database.GetIssueByIndex(c.Repo.Repository.ID, c.ParamsInt64(":index"))
	if err != nil {
		c.NotFoundOrError(err, "get issue by index")
		return nil
	}
	c.Data["Title"] = issue.Title
	c.Data["Issue"] = issue

	if !issue.IsPull {
		c.NotFound()
		return nil
	}

	if c.IsLogged {
		// Update issue-user.
		if err = issue.ReadBy(c.User.ID); err != nil {
			c.Error(err, "mark read by")
			return nil
		}
	}

	return issue
}

func PrepareMergedViewPullInfo(c *context.Context, issue *database.Issue) {
	pull := issue.PullRequest
	c.Data["HasMerged"] = true
	c.Data["HeadTarget"] = issue.PullRequest.HeadUserName + "/" + pull.HeadBranch
	c.Data["BaseTarget"] = c.Repo.Owner.Name + "/" + pull.BaseBranch

	var err error
	c.Data["NumCommits"], err = c.Repo.GitRepo.RevListCount([]string{pull.MergeBase + "..." + pull.MergedCommitID})
	if err != nil {
		c.Error(err, "count commits")
		return
	}

	names, err := c.Repo.GitRepo.DiffNameOnly(pull.MergeBase, pull.MergedCommitID, git.DiffNameOnlyOptions{NeedsMergeBase: true})
	c.Data["NumFiles"] = len(names)
	if err != nil {
		c.Error(err, "get changed files")
		return
	}
}

func PrepareViewPullInfo(c *context.Context, issue *database.Issue) *gitutil.PullRequestMeta {
	repo := c.Repo.Repository
	pull := issue.PullRequest

	c.Data["HeadTarget"] = pull.HeadUserName + "/" + pull.HeadBranch
	c.Data["BaseTarget"] = c.Repo.Owner.Name + "/" + pull.BaseBranch

	var (
		headGitRepo *git.Repository
		err         error
	)

	if pull.HeadRepo != nil {
		headGitRepo, err = git.Open(pull.HeadRepo.RepoPath())
		if err != nil {
			c.Error(err, "open repository")
			return nil
		}
	}

	if pull.HeadRepo == nil || !headGitRepo.HasBranch(pull.HeadBranch) {
		c.Data["IsPullReuqestBroken"] = true
		c.Data["HeadTarget"] = "deleted"
		c.Data["NumCommits"] = 0
		c.Data["NumFiles"] = 0
		return nil
	}

	baseRepoPath := database.RepoPath(repo.Owner.Name, repo.Name)
	prMeta, err := gitutil.Module.PullRequestMeta(headGitRepo.Path(), baseRepoPath, pull.HeadBranch, pull.BaseBranch)
	if err != nil {
		if strings.Contains(err.Error(), "fatal: Not a valid object name") {
			c.Data["IsPullReuqestBroken"] = true
			c.Data["BaseTarget"] = "deleted"
			c.Data["NumCommits"] = 0
			c.Data["NumFiles"] = 0
			return nil
		}

		c.Error(err, "get pull request meta")
		return nil
	}
	c.Data["NumCommits"] = len(prMeta.Commits)
	c.Data["NumFiles"] = prMeta.NumFiles
	return prMeta
}

func ViewPullCommits(c *context.Context) {
	c.Data["PageIsPullList"] = true
	c.Data["PageIsPullCommits"] = true

	issue := checkPullInfo(c)
	if c.Written() {
		return
	}
	pull := issue.PullRequest

	if pull.HeadRepo != nil {
		c.Data["Username"] = pull.HeadUserName
		c.Data["Reponame"] = pull.HeadRepo.Name
	}

	var commits []*git.Commit
	if pull.HasMerged {
		PrepareMergedViewPullInfo(c, issue)
		if c.Written() {
			return
		}
		startCommit, err := c.Repo.GitRepo.CatFileCommit(pull.MergeBase)
		if err != nil {
			c.Error(err, "get commit of merge base")
			return
		}
		endCommit, err := c.Repo.GitRepo.CatFileCommit(pull.MergedCommitID)
		if err != nil {
			c.Error(err, "get merged commit")
			return
		}
		commits, err = c.Repo.GitRepo.RevList([]string{startCommit.ID.String() + "..." + endCommit.ID.String()})
		if err != nil {
			c.Error(err, "list commits")
			return
		}

	} else {
		prInfo := PrepareViewPullInfo(c, issue)
		if c.Written() {
			return
		} else if prInfo == nil {
			c.NotFound()
			return
		}
		commits = prInfo.Commits
	}

	c.Data["Commits"] = matchUsersWithCommitEmails(c.Req.Context(), commits)
	c.Data["CommitsCount"] = len(commits)

	c.Success(tmplRepoPullsCommits)
}

func ViewPullFiles(c *context.Context) {
	c.Data["PageIsPullList"] = true
	c.Data["PageIsPullFiles"] = true

	issue := checkPullInfo(c)
	if c.Written() {
		return
	}
	pull := issue.PullRequest

	var (
		diffGitRepo   *git.Repository
		startCommitID string
		endCommitID   string
		gitRepo       *git.Repository
	)

	if pull.HasMerged {
		PrepareMergedViewPullInfo(c, issue)
		if c.Written() {
			return
		}

		diffGitRepo = c.Repo.GitRepo
		startCommitID = pull.MergeBase
		endCommitID = pull.MergedCommitID
		gitRepo = c.Repo.GitRepo
	} else {
		prInfo := PrepareViewPullInfo(c, issue)
		if c.Written() {
			return
		} else if prInfo == nil {
			c.NotFound()
			return
		}

		headRepoPath := database.RepoPath(pull.HeadUserName, pull.HeadRepo.Name)

		headGitRepo, err := git.Open(headRepoPath)
		if err != nil {
			c.Error(err, "open repository")
			return
		}

		headCommitID, err := headGitRepo.BranchCommitID(pull.HeadBranch)
		if err != nil {
			c.Error(err, "get head branch commit ID")
			return
		}

		diffGitRepo = headGitRepo
		startCommitID = prInfo.MergeBase
		endCommitID = headCommitID
		gitRepo = headGitRepo
	}

	diff, err := gitutil.RepoDiff(diffGitRepo,
		endCommitID, conf.Git.MaxDiffFiles, conf.Git.MaxDiffLines, conf.Git.MaxDiffLineChars,
		git.DiffOptions{Base: startCommitID, Timeout: time.Duration(conf.Git.Timeout.Diff) * time.Second},
	)
	if err != nil {
		c.Error(err, "get diff")
		return
	}
	c.Data["Diff"] = diff
	c.Data["DiffNotAvailable"] = diff.NumFiles() == 0

	commit, err := gitRepo.CatFileCommit(endCommitID)
	if err != nil {
		c.Error(err, "get commit")
		return
	}

	setEditorconfigIfExists(c)
	if c.Written() {
		return
	}

	c.Data["IsSplitStyle"] = c.Query("style") == "split"
	c.Data["IsImageFile"] = commit.IsImageFile
	c.Data["IsImageFileByIndex"] = commit.IsImageFileByIndex

	// It is possible head repo has been deleted for merged pull requests
	if pull.HeadRepo != nil {
		c.Data["Username"] = pull.HeadUserName
		c.Data["Reponame"] = pull.HeadRepo.Name

		headTarget := path.Join(pull.HeadUserName, pull.HeadRepo.Name)
		c.Data["SourcePath"] = conf.Server.Subpath + "/" + path.Join(headTarget, "src", endCommitID)
		c.Data["RawPath"] = conf.Server.Subpath + "/" + path.Join(headTarget, "raw", endCommitID)
		c.Data["BeforeSourcePath"] = conf.Server.Subpath + "/" + path.Join(headTarget, "src", startCommitID)
		c.Data["BeforeRawPath"] = conf.Server.Subpath + "/" + path.Join(headTarget, "raw", startCommitID)
	}

	c.Data["RequireHighlightJS"] = true
	c.Success(tmplRepoPullsFiles)
}

func MergePullRequest(c *context.Context) {
	issue := checkPullInfo(c)
	if c.Written() {
		return
	}
	if issue.IsClosed {
		c.NotFound()
		return
	}

	pr, err := database.GetPullRequestByIssueID(issue.ID)
	if err != nil {
		c.NotFoundOrError(err, "get pull request by issue ID")
		return
	}

	if !pr.CanAutoMerge() || pr.HasMerged {
		c.NotFound()
		return
	}

	pr.Issue = issue
	pr.Issue.Repo = c.Repo.Repository
	if err = pr.Merge(c.User, c.Repo.GitRepo, database.MergeStyle(c.Query("merge_style")), c.Query("commit_description")); err != nil {
		c.Error(err, "merge")
		return
	}

	log.Trace("Pull request merged: %d", pr.ID)
	c.Redirect(c.Repo.RepoLink + "/pulls/" + com.ToStr(pr.Index))
}

func ParseCompareInfo(c *context.Context) (*database.User, *database.Repository, *git.Repository, *gitutil.PullRequestMeta, string, string) {
	baseRepo := c.Repo.Repository

	// Get compared branches information
	// format: <base branch>...[<head repo>:]<head branch>
	// base<-head: master...head:feature
	// same repo: master...feature
	infos := strings.Split(c.Params("*"), "...")
	if len(infos) != 2 {
		log.Trace("ParseCompareInfo[%d]: not enough compared branches information %s", baseRepo.ID, infos)
		c.NotFound()
		return nil, nil, nil, nil, "", ""
	}

	baseBranch := infos[0]
	c.Data["BaseBranch"] = baseBranch

	var (
		headUser   *database.User
		headBranch string
		isSameRepo bool
		err        error
	)

	// If there is no head repository, it means pull request between same repository.
	headInfos := strings.Split(infos[1], ":")
	if len(headInfos) == 1 {
		isSameRepo = true
		headUser = c.Repo.Owner
		headBranch = headInfos[0]

	} else if len(headInfos) == 2 {
		headUser, err = database.Handle.Users().GetByUsername(c.Req.Context(), headInfos[0])
		if err != nil {
			c.NotFoundOrError(err, "get user by name")
			return nil, nil, nil, nil, "", ""
		}
		headBranch = headInfos[1]
		isSameRepo = headUser.ID == baseRepo.OwnerID

	} else {
		c.NotFound()
		return nil, nil, nil, nil, "", ""
	}
	c.Data["HeadUser"] = headUser
	c.Data["HeadBranch"] = headBranch
	c.Repo.PullRequest.SameRepo = isSameRepo

	// Check if base branch is valid.
	if !c.Repo.GitRepo.HasBranch(baseBranch) {
		c.NotFound()
		return nil, nil, nil, nil, "", ""
	}

	var (
		headRepo    *database.Repository
		headGitRepo *git.Repository
	)

	// In case user included redundant head user name for comparison in same repository,
	// no need to check the fork relation.
	if !isSameRepo {
		var has bool
		headRepo, has, err = database.HasForkedRepo(headUser.ID, baseRepo.ID)
		if err != nil {
			c.Error(err, "get forked repository")
			return nil, nil, nil, nil, "", ""
		} else if !has {
			log.Trace("ParseCompareInfo [base_repo_id: %d]: does not have fork or in same repository", baseRepo.ID)
			c.NotFound()
			return nil, nil, nil, nil, "", ""
		}

		headGitRepo, err = git.Open(database.RepoPath(headUser.Name, headRepo.Name))
		if err != nil {
			c.Error(err, "open repository")
			return nil, nil, nil, nil, "", ""
		}
	} else {
		headRepo = c.Repo.Repository
		headGitRepo = c.Repo.GitRepo
	}

	if !database.Handle.Permissions().Authorize(
		c.Req.Context(),
		c.User.ID,
		headRepo.ID,
		database.AccessModeWrite,
		database.AccessModeOptions{
			OwnerID: headRepo.OwnerID,
			Private: headRepo.IsPrivate,
		},
	) && !c.User.IsAdmin {
		log.Trace("ParseCompareInfo [base_repo_id: %d]: does not have write access or site admin", baseRepo.ID)
		c.NotFound()
		return nil, nil, nil, nil, "", ""
	}

	// Check if head branch is valid.
	if !headGitRepo.HasBranch(headBranch) {
		c.NotFound()
		return nil, nil, nil, nil, "", ""
	}

	headBranches, err := headGitRepo.Branches()
	if err != nil {
		c.Error(err, "get branches")
		return nil, nil, nil, nil, "", ""
	}
	c.Data["HeadBranches"] = headBranches

	baseRepoPath := database.RepoPath(baseRepo.Owner.Name, baseRepo.Name)
	meta, err := gitutil.Module.PullRequestMeta(headGitRepo.Path(), baseRepoPath, headBranch, baseBranch)
	if err != nil {
		if gitutil.IsErrNoMergeBase(err) {
			c.Data["IsNoMergeBase"] = true
			c.Success(tmplRepoPullsCompare)
		} else {
			c.Error(err, "get pull request meta")
		}
		return nil, nil, nil, nil, "", ""
	}
	c.Data["BeforeCommitID"] = meta.MergeBase

	return headUser, headRepo, headGitRepo, meta, baseBranch, headBranch
}

func PrepareCompareDiff(
	c *context.Context,
	headUser *database.User,
	headRepo *database.Repository,
	headGitRepo *git.Repository,
	meta *gitutil.PullRequestMeta,
	headBranch string,
) bool {
	var (
		repo = c.Repo.Repository
		err  error
	)

	// Get diff information.
	c.Data["CommitRepoLink"] = headRepo.Link()

	headCommitID, err := headGitRepo.BranchCommitID(headBranch)
	if err != nil {
		c.Error(err, "get head branch commit ID")
		return false
	}
	c.Data["AfterCommitID"] = headCommitID

	if headCommitID == meta.MergeBase {
		c.Data["IsNothingToCompare"] = true
		return true
	}

	diff, err := gitutil.RepoDiff(headGitRepo,
		headCommitID, conf.Git.MaxDiffFiles, conf.Git.MaxDiffLines, conf.Git.MaxDiffLineChars,
		git.DiffOptions{Base: meta.MergeBase, Timeout: time.Duration(conf.Git.Timeout.Diff) * time.Second},
	)
	if err != nil {
		c.Error(err, "get repository diff")
		return false
	}
	c.Data["Diff"] = diff
	c.Data["DiffNotAvailable"] = diff.NumFiles() == 0

	headCommit, err := headGitRepo.CatFileCommit(headCommitID)
	if err != nil {
		c.Error(err, "get head commit")
		return false
	}

	c.Data["Commits"] = matchUsersWithCommitEmails(c.Req.Context(), meta.Commits)
	c.Data["CommitCount"] = len(meta.Commits)
	c.Data["Username"] = headUser.Name
	c.Data["Reponame"] = headRepo.Name
	c.Data["IsImageFile"] = headCommit.IsImageFile
	c.Data["IsImageFileByIndex"] = headCommit.IsImageFileByIndex

	headTarget := path.Join(headUser.Name, repo.Name)
	c.Data["SourcePath"] = conf.Server.Subpath + "/" + path.Join(headTarget, "src", headCommitID)
	c.Data["RawPath"] = conf.Server.Subpath + "/" + path.Join(headTarget, "raw", headCommitID)
	c.Data["BeforeSourcePath"] = conf.Server.Subpath + "/" + path.Join(headTarget, "src", meta.MergeBase)
	c.Data["BeforeRawPath"] = conf.Server.Subpath + "/" + path.Join(headTarget, "raw", meta.MergeBase)
	return false
}

func CompareAndPullRequest(c *context.Context) {
	c.Data["Title"] = c.Tr("repo.pulls.compare_changes")
	c.Data["PageIsComparePull"] = true
	c.Data["IsDiffCompare"] = true
	c.Data["RequireHighlightJS"] = true
	setTemplateIfExists(c, PullRequestTemplateKey, PullRequestTemplateCandidates)
	renderAttachmentSettings(c)

	headUser, headRepo, headGitRepo, prInfo, baseBranch, headBranch := ParseCompareInfo(c)
	if c.Written() {
		return
	}

	pr, err := database.GetUnmergedPullRequest(headRepo.ID, c.Repo.Repository.ID, headBranch, baseBranch)
	if err != nil {
		if !database.IsErrPullRequestNotExist(err) {
			c.Error(err, "get unmerged pull request")
			return
		}
	} else {
		c.Data["HasPullRequest"] = true
		c.Data["PullRequest"] = pr
		c.Success(tmplRepoPullsCompare)
		return
	}

	nothingToCompare := PrepareCompareDiff(c, headUser, headRepo, headGitRepo, prInfo, headBranch)
	if c.Written() {
		return
	}

	if !nothingToCompare {
		// Setup information for new form.
		RetrieveRepoMetas(c, c.Repo.Repository)
		if c.Written() {
			return
		}
	}

	setEditorconfigIfExists(c)
	if c.Written() {
		return
	}

	c.Data["IsSplitStyle"] = c.Query("style") == "split"
	setTemplateIfExists(c, PullRequestTitleTemplateKey, PullRequestTitleTemplateCandidates)

	if c.Data[PullRequestTitleTemplateKey] != nil {
		customTitle := c.Data[PullRequestTitleTemplateKey].(string)
		r := strings.NewReplacer("{{headBranch}}", headBranch, "{{baseBranch}}", baseBranch)
		c.Data["title"] = r.Replace(customTitle)
	}

	c.Success(tmplRepoPullsCompare)
}

func CompareAndPullRequestPost(c *context.Context, f form.NewIssue) {
	c.Data["Title"] = c.Tr("repo.pulls.compare_changes")
	c.Data["PageIsComparePull"] = true
	c.Data["IsDiffCompare"] = true
	c.Data["RequireHighlightJS"] = true
	renderAttachmentSettings(c)

	var (
		repo        = c.Repo.Repository
		attachments []string
	)

	headUser, headRepo, headGitRepo, meta, baseBranch, headBranch := ParseCompareInfo(c)
	if c.Written() {
		return
	}

	labelIDs, milestoneID, assigneeID := ValidateRepoMetas(c, f)
	if c.Written() {
		return
	}

	if conf.Attachment.Enabled {
		attachments = f.Files
	}

	if c.HasError() {
		form.Assign(f, c.Data)

		// This stage is already stop creating new pull request, so it does not matter if it has
		// something to compare or not.
		PrepareCompareDiff(c, headUser, headRepo, headGitRepo, meta, headBranch)
		if c.Written() {
			return
		}

		c.Success(tmplRepoPullsCompare)
		return
	}

	patch, err := headGitRepo.DiffBinary(meta.MergeBase, headBranch)
	if err != nil {
		c.Error(err, "get patch")
		return
	}

	pullIssue := &database.Issue{
		RepoID:      repo.ID,
		Index:       repo.NextIssueIndex(),
		Title:       f.Title,
		PosterID:    c.User.ID,
		Poster:      c.User,
		MilestoneID: milestoneID,
		AssigneeID:  assigneeID,
		IsPull:      true,
		Content:     f.Content,
	}
	pullRequest := &database.PullRequest{
		HeadRepoID:   headRepo.ID,
		BaseRepoID:   repo.ID,
		HeadUserName: headUser.Name,
		HeadBranch:   headBranch,
		BaseBranch:   baseBranch,
		HeadRepo:     headRepo,
		BaseRepo:     repo,
		MergeBase:    meta.MergeBase,
		Type:         database.PullRequestTypeGogs,
	}
	// FIXME: check error in the case two people send pull request at almost same time, give nice error prompt
	// instead of 500.
	if err := database.NewPullRequest(repo, pullIssue, labelIDs, attachments, pullRequest, patch); err != nil {
		c.Error(err, "new pull request")
		return
	} else if err := pullRequest.PushToBaseRepo(); err != nil {
		c.Error(err, "push to base repository")
		return
	}

	log.Trace("Pull request created: %d/%d", repo.ID, pullIssue.ID)
	c.Redirect(c.Repo.RepoLink + "/pulls/" + com.ToStr(pullIssue.Index))
}
