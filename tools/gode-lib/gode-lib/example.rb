# frozen_string_literal: true

require "gode"

# --- The guide command ---

Gode.add("gode-lib/example", "How to create gode-lib extensions") do
  option :level, Integer, default: 0, desc: "Show specific level (1-10), default: all"

  example "gode gode-lib/example --level 2"

  run do
    levels = {
      1 => ["Minimal", <<~CODE],
        Gode.add("my/cmd", "What it does") do
          run do
            puts "hello"
          end
        end
      CODE
      2 => ["Options + positional", <<~CODE],
        Gode.add("my/cmd", "What it does") do
          option :verbose, default: false, desc: "Show details"
          option :limit, Integer, default: 10, desc: "Max results"
          positional :path, default: "."

          run do
            # verbose, limit, path available as methods
          end
        end
      CODE
      3 => ["Example (shows in --help)", <<~CODE],
        Gode.add("my/cmd", "What it does") do
          option :format, default: "text", desc: "Output format"
          positional :file, required: true

          example "gode my/cmd --format json data.csv"

          run do
            # format, file available as methods
          end
        end
      CODE
      4 => ["Lines output", <<~CODE],
        Gode.add("my/cmd", "What it does") do
          run do
            lines %w[alpha bravo charlie delta]
            # --grep "avo"  --head 2  --count
          end
        end
      CODE
      5 => ["Boot + timing", <<~CODE],
        Gode.add("my/cmd", "What it does") do
          boot { require_relative "my_lib" }

          run do
            t = time("heavy work") { sleep 0.1 }
            puts "\#{t.label}: \#{t.elapsed.round(3)}s"
          end
        end
      CODE
      6 => ["Pipe (capture subprocess output)", <<~CODE],
        Gode.add("my/cmd", "What it does") do
          run do
            pipe("git log --oneline -20")
            # Output flows through pager (--head, --grep, etc. work)
            # stderr merged by default

            # Opt out of stderr:
            pipe("noisy-tool --run", stderr: false)
          end
        end
      CODE
      7 => ["Pipe with timestamps + block grouping", <<~CODE],
        Gode.add("my/cmd", "What it does") do
          run do
            # Elapsed time per line:
            pipe("slow-build", time: :elapsed)
            # Output: [0.3s] Compiling...  [1.2s] Linking...

            # Group lines into blocks by separator:
            pipe("rspec --format documentation", block: /^\\S/)
            # Each non-indented line starts a new block.
            # --head 3 returns first 3 blocks, not lines.
          end
        end
      CODE
      8 => ["Background jobs", <<~CODE],
        Gode.add("my/cmd", "What it does") do
          run do
            job = background("long-running-server")
            # Returns Gode::Job with .pid and .log_path
            puts "PID: \#{job.pid}"
            puts "Log: \#{job.log_path}"

            # Custom log path:
            job = background("worker", log: "tmp/worker.log")
          end
        end
      CODE
      9 => ["Table with block builder (recommended)", <<~CODE],
        Gode.add("my/report", "Build table row by row") do
          run do
            table %w[name status score] do |t|
              t.row "alice", "active", "95"
              t.row "bob", "pending", "87"
              t.row "carol", "active", "92"
            end
            # Full pipeline: --grep "status:active" --cut ",name,score"
            # --count-by ",status" --sort-by ",-score"
            # --to-jsonl  --to-csv  --capabilities
          end
        end
      CODE
      10 => ["Tree (key-value from hash)", <<~CODE],
        Gode.add("my/config", "Show config") do
          run do
            tree(
              app: "gode", version: "1.1",
              db: { host: "localhost", port: 5432 }
            )
            # --grep "host:localhost"  --cut ",db"  --count
          end
        end
      CODE
      11 => ["File parsers (JSON, Markdown, YAML)", <<~CODE],
        # JSON — file: true enables --stdin
        Gode.add("my/json", "Query JSON") do
          positional :file, required: true, file: true
          run do
            render Gode::KeyValue.parse_json(file)
          end
        end
        # echo '{"a":1}' | gode my/json --stdin --grep "key:val"

        # Markdown
        Gode.add("my/md", "Query markdown") do
          positional :file, required: true
          run do
            render Gode::Markdown.parse(file).result
          end
        end
      CODE
      12 => ["Pipe command (streams)", <<~CODE],
        Gode.add("my/run", "Run and query output") do
          positional :command, required: true
          run do
            pipe(command)
            # --stdout --stderr --merge-streams --streams --raw
            # --grep "stream:stderr" --count
          end
        end
      CODE
    }

    puts "gode-lib extensions"
    puts "Source: tools/gode-lib/<name>.rb"
    puts

    show = level > 0 ? { level => levels[level] } : levels

    show.each do |n, (title, code)|
      puts "Level #{n}: #{title}"
      code.each_line { |l| puts "  #{l}" }
    end

    puts "Live demos (run these):"
    puts "  gode gode-lib/demo-options --verbose --limit 3 lib"
    puts "  gode gode-lib/demo-pager"
    puts "  gode gode-lib/demo-timing"
    puts "  gode gode-lib/demo-options --help    # auto-generated"
    puts
    puts "Create your own:"
    puts "  1. Add tools/gode-lib/my_extension.rb"
    puts "  2. Gode.add(\"group/name\", \"desc\") do ... end"
    puts "  3. gode group/name"
    puts
    puts "DSL:      option, positional, boot, run, example"
    puts "Output:   table %w[col1 col2] { |t| t.row ... }  — table"
    puts "          lines %w[a b c]  — plain text"
    puts "          tree(key: val)  — key-value"
    puts "          pipe(cmd)  — stdout+stderr stream"
    puts "          render Gode::KeyValue.parse_json(file)  — file parser"
    puts "Pipeline: --grep --search --head --tail --count --cut --count-by --sort-by"
    puts "          --to-jsonl --to-csv --out FILE --capabilities"
    puts "          --stdin --stdout --stderr --merge-streams --artifact"
  end
end

# --- Live demos ---

Gode.add("gode-lib/demo-options", "[demo] Options and positional args") do
  option :verbose, default: false, desc: "Show details"
  option :limit, Integer, default: 5, desc: "Max results"
  positional :path, default: "."

  example "gode gode-lib/demo-options --verbose --limit 3 lib"

  run do
    files = Dir.glob(File.join(path, "**/*.rb"))
      .reject { |f| f.include?("vendor") || f.include?("node_modules") }
      .sort

    puts "Path: #{path} (#{files.size} Ruby files)"
    puts

    files.first(limit).each do |f|
      if verbose
        lines = File.readlines(f).size
        puts "  %-50s %4d lines" % [f, lines]
      else
        puts "  #{f}"
      end
    end

    puts "  ... #{files.size - limit} more" if files.size > limit
  end
end

Gode.add("gode-lib/demo-pager", "[demo] Paginated output") do
  pager head: 3, tail: 2
  positional :path, default: "."

  example "gode gode-lib/demo-pager lib"

  run do
    files = Dir.glob(File.join(path, "**/*.rb"))
      .reject { |f| f.include?("vendor") || f.include?("node_modules") }
      .sort

    lines files
  end
end

Gode.add("gode-lib/demo-timing", "[demo] Timing blocks") do
  option :count, Integer, default: 3, desc: "Number of operations to time"

  example "gode gode-lib/demo-timing --count 5"

  run do
    timings = []
    count.times do |i|
      timings << time("operation #{i + 1}") do
        # Simulate work
        (1..50_000).reduce(:+)
      end
    end

    timings.each do |t|
      puts "  %-20s %7.3fs  %dk allocs" % [t.label, t.elapsed, t.allocs / 1000]
    end
    puts
    total = timings.sum(&:elapsed)
    puts "  Total: %.3fs" % total
  end
end
