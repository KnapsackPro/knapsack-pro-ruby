require 'rspec/core'

module RSpec
  def self.reset_by_knapsack_pro
    #RSpec::ExampleGroups.remove_all_constants # this is already called by our rspec_clear_examples method
    @world = nil
    #@configuration = nil # this breaks configuration
  end

  module Core
    class World
      def prepare_example_filtering#_by_knapsack_pro
        # require 'pry'; binding.pry
        @filtered_examples = Hash.new do |hash, group|
          # require 'pry'; binding.pry
          hash[group] = filter_manager.prune(group.examples)
          # hash[group] = group.examples
          # hash[group] = []
          # hash[group] = filter_manager.prune(group.examples)

          # hash[group] = group.examples

        end

        # @filtered_examples = Hash.new([])

        # @filtered_examples = {}
        # require 'pry'; binding.pry
      end
    end

    class Configuration
      def extract_location(path)
        match = /^(.*?)((?:\:\d+)+)$/.match(path)

        # require 'pry'; binding.pry

        if match
          captures = match.captures
          path = captures[0]
          lines = captures[1][1..-1].split(":").map(&:to_i)
          filter_manager.add_location path, lines
        else
          path, scoped_ids = Example.parse_id(path)
          filter_manager.add_ids(path, scoped_ids.split(/\s*,\s*/)) if scoped_ids
        end

        return [] if path == default_path
        File.expand_path(path)
      end

      # def exclusion_filter
      #   binding.pry
      #   filter_manager.exclusions
      #   # {}
      # end

    end

    # class ExclusionRules
    #   def [](key)
    #     nil
    #   end

    #   def fetch(*args, &block)
    #     nil
    #   end
    # end
  end
end

module KnapsackPro
  module Runners
    module Queue
      class RSpecRunner < BaseRunner
        def self.run(args)

          require_relative '../../formatters/rspec_queue_summary_formatter'
          require_relative '../../formatters/rspec_queue_profile_formatter_extension'

          ENV['KNAPSACK_PRO_TEST_SUITE_TOKEN'] = KnapsackPro::Config::Env.test_suite_token_rspec
          ENV['KNAPSACK_PRO_QUEUE_RECORDING_ENABLED'] = 'true'
          ENV['KNAPSACK_PRO_QUEUE_ID'] = KnapsackPro::Config::EnvGenerator.set_queue_id

          runner = new(KnapsackPro::Adapters::RSpecAdapter)

          cli_args = (args || '').split
          # if user didn't provide the format then use explicitly default progress formatter
          # in order to avoid KnapsackPro::Formatters::RSpecQueueSummaryFormatter being the only default formatter
          if !cli_args.include?('--format') && !cli_args.include?('-f')
            cli_args += ['--format', 'progress']
          end
          cli_args += [
            '--format', KnapsackPro::Formatters::RSpecQueueSummaryFormatter.to_s,
            '--default-path', runner.test_dir,
          ]

          accumulator = {
            status: :next,
            runner: runner,
            can_initialize_queue: true,
            args: cli_args,
            exitstatus: 0,
            all_test_file_paths: [],
          }
          while accumulator[:status] == :next
            accumulator = run_tests(accumulator)
          end

          Kernel.exit(accumulator[:exitstatus])
        end

        def self.run_tests(accumulator)
          runner = accumulator.fetch(:runner)
          can_initialize_queue = accumulator.fetch(:can_initialize_queue)
          args = accumulator.fetch(:args)
          exitstatus = accumulator.fetch(:exitstatus)
          all_test_file_paths = accumulator.fetch(:all_test_file_paths)

          test_file_paths = runner.test_file_paths(
            can_initialize_queue: can_initialize_queue,
            executed_test_files: all_test_file_paths
          )

          # RSpec::Core::World.define_method(:prepare_example_filtering) do
          #   @filtered_examples = Hash.new do |hash, group|
          #     # require 'pry'; binding.pry
          #     # hash[group] = filter_manager.prune(group.examples)
          #     hash[group] = group.examples
          #     # hash[group] = []
          #     # hash[group] = filter_manager.prune(group.examples)

          #     # hash[group] = group.examples
          #   end

          # end


          if test_file_paths.empty?
            unless all_test_file_paths.empty?
              KnapsackPro::Formatters::RSpecQueueSummaryFormatter.print_summary
              KnapsackPro::Formatters::RSpecQueueProfileFormatterExtension.print_summary

              log_rspec_command(args, all_test_file_paths, :end_of_queue)
            end

            KnapsackPro::Hooks::Queue.call_after_queue

            KnapsackPro::Report.save_node_queue_to_api

            return {
              status: :completed,
              exitstatus: exitstatus,
            }
          else
            subset_queue_id = KnapsackPro::Config::EnvGenerator.set_subset_queue_id
            ENV['KNAPSACK_PRO_SUBSET_QUEUE_ID'] = subset_queue_id

            KnapsackPro.tracker.reset!
            KnapsackPro.tracker.set_prerun_tests(test_file_paths)

            all_test_file_paths += test_file_paths
            cli_args = args + test_file_paths

            log_rspec_command(args, test_file_paths, :subset_queue)

            options = RSpec::Core::ConfigurationOptions.new(cli_args)
            #RSpec.configuration.load_spec_files
            # binding.pry
            exit_code = RSpec::Core::Runner.new(options).run($stderr, $stdout)
            exitstatus = exit_code if exit_code != 0

            # RSpec.world.prepare_example_filtering_by_knapsack_pro

            # binding.pry



            #RSpec.world.prepare_example_filtering




            #RSpec.reset_by_knapsack_pro
            #w=RSpec.world
            #require 'pry'; binding.pry

            #RSpec.configuration.clear_filters
            #RSpec.configuration.reset_filters
            rspec_clear_examples
            #RSpec.configuration.filter_run_including({})
            #a=RSpec.world.filtered_examples
            #a=RSpec.world.prepare_example_filtering
            #a=RSpec.world.reset
            #a=RSpec.world.inclusion_filter
            #RSpec.world.example_groups.clear
            #RSpec.world.inclusion_filter.clear
            #RSpec.world.exclusion_filter.clear


            KnapsackPro::Hooks::Queue.call_after_subset_queue

            KnapsackPro::Report.save_subset_queue_to_file

            return {
              status: :next,
              runner: runner,
              can_initialize_queue: false,
              args: args,
              exitstatus: exitstatus,
              all_test_file_paths: all_test_file_paths,
            }
          end
        end

        private

        def self.log_rspec_command(cli_args, test_file_paths, type)
          case type
          when :subset_queue
            KnapsackPro.logger.info("To retry in development the subset of tests fetched from API queue please run below command on your machine. If you use --order random then remember to add proper --seed 123 that you will find at the end of rspec command.")
          when :end_of_queue
            KnapsackPro.logger.info("To retry in development the tests for this CI node please run below command on your machine. It will run all tests in a single run. If you need to reproduce a particular subset of tests fetched from API queue then above after each request to Knapsack Pro API you will find example rspec command.")
          end

          stringify_cli_args = cli_args.join(' ')
          stringify_cli_args.slice!("--format #{KnapsackPro::Formatters::RSpecQueueSummaryFormatter}")

          KnapsackPro.logger.info(
            "bundle exec rspec #{stringify_cli_args} " +
            KnapsackPro::TestFilePresenter.stringify_paths(test_file_paths)
          )
        end

        # Clear rspec examples without the shared examples:
        # https://github.com/rspec/rspec-core/pull/2379
        #
        # Keep formatters and report to accumulate info about failed/pending tests
        def self.rspec_clear_examples
          if RSpec::ExampleGroups.respond_to?(:remove_all_constants)
            RSpec::ExampleGroups.remove_all_constants
          else
            RSpec::ExampleGroups.constants.each do |constant|
              RSpec::ExampleGroups.__send__(:remove_const, constant)
            end
          end
          RSpec.world.example_groups.clear
          RSpec.configuration.start_time = ::RSpec::Core::Time.now

          # skip reset filters for old RSpec versions
          if RSpec.configuration.respond_to?(:reset_filters)
            RSpec.configuration.reset_filters
          end
        end
      end
    end
  end
end
