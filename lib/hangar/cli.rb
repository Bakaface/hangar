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
      "rename"    => :cmd_rename,
      "init"      => :cmd_init,
      "edit"      => :cmd_edit,
      "mark"      => :cmd_mark,
      "generate-bindings" => :cmd_bindings,
      "templates" => :cmd_templates,
      "template"  => :cmd_template,
      "up"        => :cmd_up,
      "bootstrap" => :cmd_bootstrap,
    }.freeze

    ALIASES = {
      "o"  => "open",
      "u"  => "up",
      "k"  => "kill",
      "l"  => "list",
      "ls" => "list",
      "s"  => "sessions",
      "ss" => "sessions",
      "sw" => "switch",
      "a"  => "add",
      "rm" => "remove",
      "mv" => "rename",
      "i"  => "init",
      "ip" => "init",
      "e"  => "edit",
      "m"  => "mark",
      "b"  => "bootstrap",
      "gb" => "generate-bindings",
      "ts" => "templates",
      "t"  => "template",
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

      command = ALIASES.fetch(command, command)
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
          open, o [query]           Open/create session for a project
          kill, k [query]           Kill a running session
          list, l, ls               List registered projects
          sessions, s, ss           List running tmux sessions
          switch, sw                Fuzzy-pick a running session to switch to
          add, a [path] [--as N]    Register a project (defaults to cwd) with optional alias
          remove, rm [query]        Unregister a project
          rename, mv <query> <name> Rename a project's alias (empty name clears it)
          init, i, ip [template]    Create .hangar.sh in cwd from a template
          bootstrap, b [template]   init + add + start session detached
          edit, e [query]           Edit a project's .hangar.sh
          mark, m set <keys>        Set a mark on current session
          mark, m get [session]     Get the mark for a session
          mark, m goto              Interactive mark selector
          mark, m list              List all marks
          generate-bindings, gb [--bind]
                                    Generate tmux keybindings
          templates, ts             List available templates
          template, t new <name>    Create a new template
          template, t edit <name>   Edit a template
          up, u                     Start all configured startup projects
          version                   Show version
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

    def self.cmd_rename(args)
      if args.size < 2
        $stderr.puts "Usage: hangar rename <query> <new-name>"
        exit 1
      end
      Project.rename(args[0], args[1])
    end

    def self.cmd_init(args)
      template = args.first || Config.default_template
      Hooks.run("before-init", HANGAR_TEMPLATE: template)
      Template.init(template)
      Hooks.run("after-init", HANGAR_TEMPLATE: template)
    end

    def self.cmd_bootstrap(args)
      template = args.first || Config.default_template
      Hooks.run("before-init", HANGAR_TEMPLATE: template)
      Template.init(template)
      Hooks.run("after-init", HANGAR_TEMPLATE: template)
      Project.add(Dir.pwd)
      name = Project.session_name(Dir.pwd)
      case Session.start(Dir.pwd)
      when :started        then puts "Started session: #{name}"
      when :already_running then puts "Already running: #{name}"
      end
      Bindings.generate(bind: true) if Session.inside_tmux?
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

    def self.cmd_up(_args)
      Session.up
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
