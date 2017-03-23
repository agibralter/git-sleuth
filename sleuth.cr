require "csv"

class Info
    @dir : String
    @since : String
    @include_dirs : String
    @ignore_files : String

    def initialize(args : Array(String))
        if args.size < 2
            puts "Usage: ./sleuth <path-to-git-dir> <start-date>"
            exit 1
        end

        @dir = File.expand_path(args[0])
        @since = args[1]

        @include_dirs = args.size > 2 ? args[2] : ""

        @ignore_files = args.size > 3 ? args[3] : ""
    end

    def print
        if !File.directory?(File.join(@dir, ".git"))
            puts "Not a git directory!"
            exit 1
        end

        authors_file_stats = Hash(String, Hash(String, Array(Int32))).new

        git_authors.each do |author|
            authors_file_stats[author] = file_stats_for_author(author)
        end

        result = CSV.build do |csv|
            authors_file_stats.each do |author, file_stats|
                file_stats.each do |file_path, (lines_added, lines_removed)|
                    if lines_added > 0 || lines_removed > 0
                        csv.row [author, file_path, lines_added, lines_removed]
                    end
                end
            end
        end

        File.write("sleuth.csv", result)
    end

    private def git_authors
        gitlog("--format=\"%aN\"").uniq.reject(&.empty?)
    end

    private def gitlog(args : String)
        run("git log --all --no-merges --since=\"#{@since}\" #{args}").each_line
    end

    private def run(command : String)
        process = Process.new(
            command,
            shell: true,
            input: true,
            output: nil,
            error: true,
            chdir: @dir,
        )
        output = process.output.gets_to_end
        status = process.wait
        $? = status
        output
    end

    private def file_stats_for_author(author : String)
        file_stats = Hash(String, Array(Int32)).new
        files_touched_by(author).each do |file_path, count|
            stats = stats_for_file(author, file_path)
            file_stats[file_path] ||= [0, 0]
            file_stats[file_path][0] += stats[0]
            file_stats[file_path][1] += stats[1]
        end
        file_stats
    end

    private def files_touched_by(author : String)
        files = Hash(String, Int32).new
        git_commits_by_author(author).each do |commit|
            git_files_touched_in_commit(commit).each do |file_path|
                if include_file?(file_path)
                    files[file_path] ||= 0
                    files[file_path] += 1
                end
            end
        end
        files
    end

    private def git_commits_by_author(author)
        gitlog("--author=\"#{author}\" --pretty=\"%H\"").reject(&.empty?)
    end

    private def git_files_touched_in_commit(commit)
        gitshow("--oneline --name-only #{commit}").skip(1).reject(&.empty?)
    end

    private def gitshow(args : String)
        run("git show #{args}").each_line
    end

    private def include_file?(file_path : String)
        return true if @include_dirs.empty? && !@ignore_files.empty?
        file_path =~ include_dirs_regex ? true : false
    end

    private def include_dirs_regex
        dirs = @include_dirs.split(/\s*,\s*/).map { |dir| Regex.escape(dir) }.join("|")
        Regex.new("\\A(#{dirs})")
    end

    # Sum the stats from `git_log_for_author_and_file`.
    private def stats_for_file(author : String, file_path : String)
        totals = [0, 0]
        git_log_for_author_and_file(author, file_path).each do |arr|
            totals[0] += arr[0]
            totals[1] += arr[1]
        end
        totals
    end

    # Given a author and a file, take the git output from this:
    #
    #     $ git log --numstat --oneline --author="Bob" -- some_file
    #     xxxxxxxxx Ship the widget
    #     0       2       some_file
    #     xxxxxxxxx Adjust the toggle
    #     17      3       some_file
    #     xxxxxxxxx Flip the bit
    #     9       0       some_file
    #
    # filter out commit messages, and map to array:
    #
    #     [<lines_added>, <lines_removed>, <file_path>]
    #
    private def git_log_for_author_and_file(author : String, file_path : String)
        # --follow: follow renames so it does not look like a file was created
        # -w: ignore whitespace changes
        gitlog("--numstat --oneline --follow -w --author=\"#{author}\" -- #{file_path}").
            reject(&.match(/^[0-9a-f]{9}/)).
            reject(&.empty?).
            map(&.split(/\s+/)).
            map(&.first(2)).
            # Handle binary files which return `-` in the git output.
            map(&.map { |s| s == "-" ? 0 : s.to_i })
    end
end

Info.new(ARGV).print
