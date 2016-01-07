require 'cgi'
require 'json'
require 'highline/import'
require 'shellwords'
require_relative "commands/base"
require_relative 'commands/check_for_local_mods'
require_relative 'commands/create_pull_request'

module Startling
  class Command < Commands::Base
    RUN = "run"

    def self.run(attrs={})
      load_configuration

      options = Startling::CliOptions.parse
      options.merge!(attrs)
      options.merge({argv: ARGV, args: ARGV})

      load_commands
      load_handlers
      super(options)
    end

    def execute
      Commands::CheckForLocalMods.run(git: git)
      command_args = cli_options.merge(git: git)

      # Before Start Story
      Startling.hook_commands.before_story_start.map do |command|
        command_class(command).send(RUN, command_args)
      end

      # Start story
      story = command_class(Startling.story_handler)
        .send(RUN, command_args) if Startling.story_handler
      command_args.merge!(story: story)

      # After Story Start
      Startling.hook_commands.after_story_start.map do |command|
        command_class(command)
          .send(RUN, command_args)
      end

      #Before Pull Request Creation
      Startling.hook_commands.before_pull_request.map do |command|
        command_class(command)
          .send(RUN, command_args)
      end

      # Create pull request
      pull_request = command_class(:create_pull_request)
        .send(RUN, command_args)
      command_args.merge!(pull_request: pull_request)

      # After Pull Request Creation
      Startling.hook_commands.after_pull_request.map do |command|
        command_class(command)
          .send(RUN, command_args)
      end
    end

    def git
      @git ||= GitLocal.new
    end
  end
end
