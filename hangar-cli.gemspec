require_relative "lib/hangar/version"

Gem::Specification.new do |s|
  s.name        = "hangar-cli"
  s.version     = Hangar::VERSION
  s.summary     = "Tmux session & project manager"
  s.description = "CLI tool for managing tmux sessions as project workspaces with marks, keybindings, and project-local configs."
  s.authors     = ["Albert"]
  s.homepage    = "https://github.com/Bakaface/hangar"
  s.license     = "MIT"

  s.required_ruby_version = ">= 3.1.0"

  s.files         = Dir["lib/**/*.rb", "bin/*", "share/**/*"]
  s.bindir        = "bin"
  s.executables   = ["hangar"]

  s.metadata = {
    "source_code_uri" => "https://github.com/Bakaface/hangar",
    "rubygems_mri_only" => "true"
  }
end
