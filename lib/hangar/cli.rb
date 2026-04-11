require "fileutils"

module Hangar
  module CLI
    COMMANDS = {
      "open"      => :cmd_open,
      "kill"      => :cmd_kill,
      "list"      => :cmd_list,
      "sessions"  => :cmd_sessions,
      "switch"    => :cmd_switch,
      "add"       => :cmd_add,
      "remove"    => :cmd_remove,
      "init"      => :cmd_init,
      "edit"      => :cmd_edit,
      "mark"      => :cmd_mark,
      "bindings"  => :cmd_bindings,
      "templates" => :cmd_templates,
      "template"  => :cmd_template,
    }.freeze

    def self.run(args)
      command = args.shift

      if command.nil? || command == "help" || command == "--help" || command == "-h"
        print_usage
        return
      end

      if command == "version" || command == "--version" || command == "-v"
        puts "hangar #{Hangar::VERSION}"
        return
      end

      method = COMMANDS[command]
      if method.nil?
        $stderr.puts "hangar: unknown command '#{command}'"
        $stderr.puts "Run 'hangar help' for usage."
        exit 1
      end

      send(method, args)
    end

    def self.print_usage
      puts <<~USAGE
        hangar #{Hangar::VERSION} — tmux session & project manager

        Usage: hangar <command> [args]

        Commands:
          open [query]          Open/create session for a project
          kill [query]          Kill a running session
          list                  List registered projects
          sessions              List running tmux sessions
          switch                Fuzzy-pick a running session to switch to
          add [path] [--as N]   Register a project (defaults to cwd) with optional alias
          remove [query]        Unregister a project
          init [template]       Create .hangar.sh in cwd from a template
          edit [query]          Edit a project's .hangar.sh
          mark set <keys>       Set a mark on current session
          mark get [session]    Get the mark for a session
          mark goto             Interactive mark selector
          mark list             List all marks
          bindings [--bind]     Generate tmux keybindings
          templates             List available templates
          template new <name>   Create a new template
          template edit <name>  Edit a template
          version               Show version
      USAGE
    end

    def self.cmd_open(args)
      Session.open(args.first)
    end

    def self.cmd_kill(args)
      Session.kill(args.first)
    end

    def self.cmd_list(_args)
      Project.list
    end

    def self.cmd_sessions(_args)
      Session.list
    end

    def self.cmd_switch(_args)
      Session.switch
    end

    def self.cmd_add(args)
      path = nil
      aliaz = nil
      while (arg = args.shift)
        if arg == "--as"
          aliaz = args.shift
        else
          path = arg
        end
      end
      Project.add(path || Dir.pwd, aliaz)
    end

    def self.cmd_remove(args)
      Project.remove(args.first)
    end

    def self.cmd_init(args)
      Template.init(args.first || "basic")
    end

    def self.cmd_edit(args)
      Project.edit(args.first)
    end

    def self.cmd_mark(args)
      sub = args.shift
      case sub
      when "set"  then Marks.set(args.first)
      when "get"  then Marks.get(args.first)
      when "goto" then Marks.goto
      when "list" then Marks.list
      else
        $stderr.puts "hangar: unknown mark subcommand '#{sub}'"
        exit 1
      end
    end

    def self.cmd_bindings(args)
      Bindings.generate(bind: args.include?("--bind"))
    end

    def self.cmd_templates(_args)
      Template.list
    end

    def self.cmd_template(args)
      sub = args.shift
      case sub
      when "new"  then Template.create(args.first)
      when "edit" then Template.edit(args.first)
      else
        $stderr.puts "hangar: unknown template subcommand '#{sub}'"
        exit 1
      end
    end
  end
end
