require "shellwords"

module Hangar
  module Bindings
    GOTO_TABLE = "goto"

    def self.generate(bind: false)
      shortcuts = collect_shortcuts
      marks = Marks.load_marks

      commands = build_keybindings(shortcuts, marks)

      if bind
        commands.each { |args| system("tmux", *args) }
      else
        commands.each { |args| puts "tmux #{args.map { |a| Shellwords.escape(a) }.join(" ")}" }
      end
    end

    def self.bind_key_sequence(keys, session)
      created = Set.new
      commands = key_chain_commands(GOTO_TABLE, keys, session, created)
      commands.each { |args| system("tmux", *args) }
    end

    def self.collect_shortcuts
      shortcuts = {}
      Project.load_registry.each do |path|
        config = File.join(path, Config.config_filename)
        next unless File.exist?(config)

        File.readlines(config).each do |line|
          if line =~ /^\s*shortcut\s+["']([^"']+)["']/
            shortcuts[$1] = Project.session_name(path)
          end
        end
      end
      shortcuts
    end

    def self.build_keybindings(shortcuts, marks)
      commands = []
      created = Set.new

      # Static shortcuts first
      shortcuts.each do |keys, session|
        commands.concat(key_chain_commands(GOTO_TABLE, keys, session, created))
      end

      # Marks override shortcuts (same goto table)
      marks.each do |keys, session|
        commands.concat(key_chain_commands(GOTO_TABLE, keys, session, created))
      end

      commands
    end

    def self.key_chain_commands(table_prefix, keys, session, created)
      commands = []
      chars = keys.chars

      chars.each_with_index do |char, i|
        table = i == 0 ? table_prefix : "#{table_prefix}-#{keys[0...i]}"

        if i == chars.length - 1
          # Final key: switch to session with fallback message
          commands << [
            "bind-key", "-T", table, char, "run-shell",
            "tmux switch-client -t '#{session}' 2>/dev/null || tmux display-message 'Session \"#{session}\" not running'"
          ]
        else
          # Intermediate key: switch to next key-table
          next_prefix = keys[0..i]
          next_table = "#{table_prefix}-#{next_prefix}"
          intermediate_key = "#{table}:#{char}"

          unless created.include?(intermediate_key)
            commands << ["bind-key", "-T", table, char, "switch-client", "-T", next_table]
            created.add(intermediate_key)
          end
        end
      end

      commands
    end
  end
end
