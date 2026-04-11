require "io/console"

module Hangar
  module Marks
    def self.set(keys)
      if keys.nil? || keys.empty?
        $stderr.puts "Usage: hangar mark set <keys>"
        exit 1
      end

      session = current_session
      if session.nil?
        $stderr.puts "Not in a tmux session"
        exit 1
      end

      marks = load_marks
      # Remove any existing mark for this session or this key sequence
      marks.reject! { |k, v| v == session || k == keys }
      marks[keys] = session
      save_marks(marks)

      # Immediately bind the mark
      Bindings.bind_key_sequence(keys, session)
      system("tmux", "display-message", "Mark '#{keys}' → #{session}")
    end

    def self.get(session = nil)
      session ||= current_session
      if session.nil?
        $stderr.puts "Not in a tmux session and no session specified"
        exit 1
      end

      marks = load_marks
      mark = marks.find { |_k, v| v == session }
      if mark
        puts mark.first
      else
        $stderr.puts "No mark for session '#{session}'"
        exit 1
      end
    end

    def self.goto
      running = Session.running_session_names
      marks = load_marks.select { |_k, v| running.include?(v) }
      if marks.empty?
        puts "No marks for running sessions"
        sleep 1
        return
      end

      input = ""
      display_marks(marks, input)

      loop do
        char = $stdin.getch

        # Escape or Ctrl-C → cancel
        break if char == "\e" || char == "\x03"

        input += char
        display_marks(marks, input)

        # Exact match → switch
        if marks.key?(input)
          session = marks[input]
          system("tmux", "switch-client", "-t", session, err: File::NULL) ||
            puts("\nSession \"#{session}\" not running")
          return
        end

        # No prefix matches → exit
        unless marks.keys.any? { |k| k.start_with?(input) }
          puts "\nNo match for '#{input}'"
          sleep 0.5
          return
        end
      end
    end

    def self.list
      marks = load_marks
      if marks.empty?
        puts "No marks set"
        return
      end

      marks.each { |k, v| puts "#{k}\t#{v}" }
    end

    def self.load_marks
      return {} unless File.exist?(Config.marks_file)

      marks = {}
      File.readlines(Config.marks_file).each do |line|
        line = line.strip
        next if line.empty?
        key, session = line.split("=", 2)
        marks[key] = session if key && session
      end
      marks
    end

    def self.save_marks(marks)
      Config.ensure_data_dir
      File.write(Config.marks_file, marks.map { |k, v| "#{k}=#{v}" }.join("\n") + "\n")
    end

    def self.current_session
      name = `tmux display-message -p '\#{session_name}' 2>/dev/null`.strip
      name.empty? ? nil : name
    end

    private_class_method def self.display_marks(marks, input)
      print "\e[2J\e[H" # clear screen, cursor to top
      puts "\e[1mGoto mark:\e[0m #{input}\n\n"

      marks.each do |k, v|
        if input.empty? || k.start_with?(input)
          printf "  \e[33m%-4s\e[0m  %s\n", k, v
        else
          printf "  \e[90m%-4s  %s\e[0m\n", k, v
        end
      end
    end
  end
end
