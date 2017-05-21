# GitLab Event Parsing
class GitLabParser
  def GitLabParser.parse(json)
    j = RecursiveOpenStruct.new(json)
    response = []
    kind = j.object_kind
    case kind
    when 'note'
      repo = j.project.path_with_namespace
      ntype = j.object_attributes.noteable_type
      case ntype
      when 'MergeRequest'
        mr_note  = j.object_attributes.note
        mr_url   = shorten(j.object_attributes.url)
        mr_title = j.merge_request.title
        mr_id    = j.merge_request.iid
        mr_user  = j.user.name
        response << "[#{repo}] #{mr_user} commented on Merge Request ##{mr_id} \u2014 #{mr_note}"
        response << "'#{mr_title}' => #{mr_url}"
      when 'Commit'
        c_message = j.commit.message
        c_note    = j.object_attributes.note
        c_sha     = j.commit.id[0...7]
        c_url     = shorten(j.object_attributes.url)
        c_user    = j.user.name
        response << "[#{repo}] #{c_user} commented on commit (#{c_sha}) \u2014 #{c_note} <#{c_url}>"
      when 'Issue'
        i_id    = j.issue.iid
        i_url   = shorten(j.object_attributes.url)
        i_msg   = j.object_attributes.note
        i_title = j.issue.title
        i_user  = j.user.name
        response << "[#{repo}] #{i_user} commented on Issue ##{i_id} (#{i_title}) \u2014 #{i_msg} <#{i_url}>"
      end
    when 'issue'
      i_repo   = j.project.path_with_namespace
      i_id     = j.object_attributes.iid
      i_title  = j.object_attributes.title
      i_action = j.object_attributes.action
      i_url    = shorten(j.object_attributes.url)
    when 'merge_request'
      mr_name      = j.user.name
      mr_user      = j.user.username
      mr_url       = shorten(j.url)
      mr_spath     = j.object_attributes.source.path_with_namespace
      mr_sbranch   = j.object_attributes.source_branch
      mr_tpath     = j.object_attributes.target.path_with_namespace
      mr_tbranch   = j.object_attributes.target_branch
      mr_lcmessage = j.object_attributes.last_commit.message
      mr_lcsha     = j.object_attributes.last_commit.id[0...7]
      response = []
      response << "#{mr_name}(#{mr_user}) opened a merge request. #{mr_spath}[#{mr_sbranch}] ~> #{mr_tpath}[#{mr_tbranch}]"
      response << "[#{mr_lcsha}] \u2014 #{mr_lcmessage} <#{mr_url}>"
    when 'push' # comes to
      # shove
      branch = j.ref.split('/')[-1]
      commits = j.commits
      added = 0
      removed = 0
      modified = 0
      commits.each do |h|
        added    += h["added"].length
        removed  += h["removed"].length
        modified += h["modified"].length
      end
      owner = j.project.namespace
      project = j.project.name
      pusher = j.user_name
      commit_count = j.total_commits_count
      repo_url = shorten(j.project.web_url)
      response << "[#{owner}/#{project}] #{pusher} pushed #{commit_count} commit(s) [+#{added}/-#{removed}/±#{modified}] to [#{branch}] at <#{repo_url}>"
      if commits.length > 3
        coms = commits[0..2]
        coms.each do |n|
          id = n["id"]
          msg = n["message"]
          author = n["author"]["name"]
          timestamp = n["timestamp"]
          ts = DateTime.parse(timestamp)
          time = ts.strftime("%b/%d/%Y %T")
          response << "#{author} — #{msg} [#{id[0...7]}]"
        end
        response << "and #{commits.from(3).length} commits..."
      else
        commits.each do |n|
          id = n['id'][0...7]
          msg = n['message']
          author = n['author']['name']
          timestamp = n['timestamp']
          ts = DateTime.parse(timestamp)
          time = ts.strftime("%b/%d/%Y %T")
          response << "#{author} — #{msg} [#{id}]"
        end
      end
    end
    return response
  end
end