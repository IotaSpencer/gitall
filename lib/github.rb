# GitHub Event Parsing

class GitHubParser
	def GitHubParser.parse(json, event)
    j = RecursiveOpenStruct.new(json)
    response = []

    case event
    when 'push'
      repo = j.repository.full_name
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
      pusher = j.pusher.name
      commit_count = j.size
      compare_url = shorten(j.compare)
      response << "[#{repo}] #{pusher} pushed #{commit_count} commit(s) [+#{added}/-#{removed}/±#{modified}] to [#{branch}] <#{compare_url}>"
      if commits.length > 3
        coms = commits[0..2]
        coms.each do |n|
          id = n.dig(:id)[0...7]
          msg = n.dig :message
          author = n.dig :committer, :name
          response << "#{author} — #{msg} [#{id[0...7]}]"
        end
        response << "and #{commits.from(3).length} commits..."
      else
        commits.each do |n|
          id = n.dig(:id)[0...7]
          msg = n.dig :message
          author = n.dig :committer, :name
          response << "#{author} — #{msg} [#{id}]"
        end
      end      
    end
    return response
  end
end