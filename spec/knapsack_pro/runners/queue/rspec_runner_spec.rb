describe KnapsackPro::Runners::Queue::RSpecRunner do
  before do
    # we don't want to modify rspec formatters because we want to see tests summary at the end
    # when you run this test file or whole test suite for the knapsack_pro gem
    stub_const('ENV', { 'KNAPSACK_PRO_MODIFY_DEFAULT_RSPEC_FORMATTERS' => false })

    require KnapsackPro.root + '/lib/knapsack_pro/formatters/rspec_queue_summary_formatter'
    require KnapsackPro.root + '/lib/knapsack_pro/formatters/rspec_queue_profile_formatter_extension'
  end

  describe '.run' do
    let(:test_suite_token_rspec) { 'fake-token' }
    let(:queue_id) { 'fake-queue-id' }
    let(:test_dir) { 'fake-test-dir' }
    let(:runner) do
      instance_double(described_class, test_dir: test_dir)
    end

    subject { described_class.run(args) }

    before do
      expect(KnapsackPro::Config::Env).to receive(:test_suite_token_rspec).and_return(test_suite_token_rspec)
      expect(KnapsackPro::Config::EnvGenerator).to receive(:set_queue_id).and_return(queue_id)

      expect(ENV).to receive(:[]=).with('KNAPSACK_PRO_TEST_SUITE_TOKEN', test_suite_token_rspec)
      expect(ENV).to receive(:[]=).with('KNAPSACK_PRO_QUEUE_RECORDING_ENABLED', 'true')
      expect(ENV).to receive(:[]=).with('KNAPSACK_PRO_QUEUE_ID', queue_id)

      expect(KnapsackPro::Config::Env).to receive(:set_test_runner_adapter).with(KnapsackPro::Adapters::RSpecAdapter)

      expect(described_class).to receive(:new).with(KnapsackPro::Adapters::RSpecAdapter).and_return(runner)
    end

    context 'when args provided' do
      context 'when format option is not provided' do
        let(:args) { '--example-arg example-value' }

        it 'uses default formatter progress' do
          expected_exitstatus = 0
          expected_accumulator = {
            status: :completed,
            exitstatus: expected_exitstatus
          }
          accumulator = {
            status: :next,
            runner: runner,
            can_initialize_queue: true,
            args: ['--example-arg', 'example-value', '--format', 'progress', '--format', 'KnapsackPro::Formatters::RSpecQueueSummaryFormatter', '--default-path', 'fake-test-dir'],
            exitstatus: 0,
            all_test_file_paths: [],
          }
          expect(described_class).to receive(:run_tests).with(accumulator).and_return(expected_accumulator)

          expect(Kernel).to receive(:exit).with(expected_exitstatus)

          subject
        end
      end

      context 'when format option is provided as --format' do
        let(:args) { '--format documentation' }

        it 'uses provided format option instead of default formatter progress' do
          expected_exitstatus = 0
          expected_accumulator = {
            status: :completed,
            exitstatus: expected_exitstatus
          }
          accumulator = {
            status: :next,
            runner: runner,
            can_initialize_queue: true,
            args: ['--format', 'documentation', '--format', 'KnapsackPro::Formatters::RSpecQueueSummaryFormatter', '--default-path', 'fake-test-dir'],
            exitstatus: 0,
            all_test_file_paths: [],
          }
          expect(described_class).to receive(:run_tests).with(accumulator).and_return(expected_accumulator)

          expect(Kernel).to receive(:exit).with(expected_exitstatus)

          subject
        end
      end

      context 'when format option is provided as -f' do
        let(:args) { '-f d' }

        it 'uses provided format option instead of default formatter progress' do
          expected_exitstatus = 0
          expected_accumulator = {
            status: :completed,
            exitstatus: expected_exitstatus
          }
          accumulator = {
            status: :next,
            runner: runner,
            can_initialize_queue: true,
            args: ['-f', 'd', '--format', 'KnapsackPro::Formatters::RSpecQueueSummaryFormatter', '--default-path', 'fake-test-dir'],
            exitstatus: 0,
            all_test_file_paths: [],
          }
          expect(described_class).to receive(:run_tests).with(accumulator).and_return(expected_accumulator)

          expect(Kernel).to receive(:exit).with(expected_exitstatus)

          subject
        end
      end

      context 'when format option is provided without a delimiter' do
        let(:args) { '-fMyCustomFormatter' }

        it 'uses provided format option instead of default formatter progress' do
          expected_exitstatus = 0
          expected_accumulator = {
            status: :completed,
            exitstatus: expected_exitstatus
          }
          accumulator = {
            status: :next,
            runner: runner,
            can_initialize_queue: true,
            args: ['-fMyCustomFormatter', '--format', 'KnapsackPro::Formatters::RSpecQueueSummaryFormatter', '--default-path', 'fake-test-dir'],
            exitstatus: 0,
            all_test_file_paths: [],
          }
          expect(described_class).to receive(:run_tests).with(accumulator).and_return(expected_accumulator)

          expect(Kernel).to receive(:exit).with(expected_exitstatus)

          subject
        end
      end

      context 'when RSpec split by test examples feature is enabled' do
        before do
          expect(KnapsackPro::Config::Env).to receive(:rspec_split_by_test_examples?).and_return(true)
          expect(KnapsackPro::Adapters::RSpecAdapter).to receive(:ensure_no_tag_option_when_rspec_split_by_test_examples_enabled!).and_call_original
        end

        context 'when tag option is provided' do
          let(:args) { '--tag example-value' }

          it do
            expect { subject }.to raise_error(/It is not allowed to use the RSpec tag option together with the RSpec split by test examples feature/)
          end
        end
      end
    end

    context 'when args not provided' do
      let(:args) { nil }

      it do
        expected_exitstatus = 0
        expected_accumulator = {
          status: :completed,
          exitstatus: expected_exitstatus
        }
        accumulator = {
          status: :next,
          runner: runner,
          can_initialize_queue: true,
          args: ['--format', 'progress', '--format', 'KnapsackPro::Formatters::RSpecQueueSummaryFormatter', '--default-path', 'fake-test-dir'],
          exitstatus: 0,
          all_test_file_paths: [],
        }
        expect(described_class).to receive(:run_tests).with(accumulator).and_return(expected_accumulator)

        expect(Kernel).to receive(:exit).with(expected_exitstatus)

        subject
      end
    end
  end

  describe '.run_tests' do
    let(:runner) { instance_double(described_class) }
    let(:can_initialize_queue) { double(:can_initialize_queue) }
    let(:args) { ['--no-color', '--default-path', 'fake-test-dir'] }
    let(:exitstatus) { double }
    let(:all_test_file_paths) { [] }
    let(:accumulator) do
      {
        runner: runner,
        can_initialize_queue: can_initialize_queue,
        args: args,
        exitstatus: exitstatus,
        all_test_file_paths: all_test_file_paths,
      }
    end

    subject { described_class.run_tests(accumulator) }

    before do
      expect(runner).to receive(:test_file_paths).with(can_initialize_queue: can_initialize_queue, executed_test_files: all_test_file_paths).and_return(test_file_paths)
    end

    context 'when test files exist' do
      let(:test_file_paths) { ['a_spec.rb', 'b_spec.rb'] }
      let(:logger) { double }
      let(:rspec_seed) { 7771 }

      before do
        subset_queue_id = 'fake-subset-queue-id'
        expect(KnapsackPro::Config::EnvGenerator).to receive(:set_subset_queue_id).and_return(subset_queue_id)

        expect(ENV).to receive(:[]=).with('KNAPSACK_PRO_SUBSET_QUEUE_ID', subset_queue_id)

        tracker = instance_double(KnapsackPro::Tracker)
        expect(KnapsackPro).to receive(:tracker).twice.and_return(tracker)
        expect(tracker).to receive(:reset!)
        expect(tracker).to receive(:set_prerun_tests).with(test_file_paths)

        options = double
        expect(RSpec::Core::ConfigurationOptions).to receive(:new).with([
          '--no-color',
          '--default-path', 'fake-test-dir',
          'a_spec.rb', 'b_spec.rb',
        ]).and_return(options)

        rspec_core_runner = double
        expect(RSpec::Core::Runner).to receive(:new).with(options).and_return(rspec_core_runner)
        expect(rspec_core_runner).to receive(:run).with($stderr, $stdout).and_return(exit_code)

        expect(described_class).to receive(:rspec_clear_examples)

        expect(KnapsackPro::Hooks::Queue).to receive(:call_before_subset_queue)

        expect(KnapsackPro::Hooks::Queue).to receive(:call_after_subset_queue)

        expect(KnapsackPro::Report).to receive(:save_subset_queue_to_file)

        configuration = double
        expect(rspec_core_runner).to receive(:configuration).twice.and_return(configuration)
        expect(configuration).to receive(:seed_used?).and_return(true)
        expect(configuration).to receive(:seed).and_return(rspec_seed)

        expect(KnapsackPro).to receive(:logger).twice.and_return(logger)
        expect(logger).to receive(:info)
          .with("To retry the last batch of tests fetched from the API Queue, please run the following command on your machine:")
        expect(logger).to receive(:info).with(/#{args.join(' ')} --seed #{rspec_seed}/)
      end

      context 'when exit code is zero' do
        let(:exit_code) { 0 }

        it do
          expect(subject).to eq({
            status: :next,
            runner: runner,
            can_initialize_queue: false,
            args: args,
            exitstatus: exitstatus,
            all_test_file_paths: test_file_paths,
          })
        end
      end

      context 'when exit code is not zero' do
        let(:exit_code) { double }

        it do
          expect(subject).to eq({
            status: :next,
            runner: runner,
            can_initialize_queue: false,
            args: args,
            exitstatus: exit_code,
            all_test_file_paths: test_file_paths,
          })
        end
      end
    end

    context "when test files don't exist" do
      let(:test_file_paths) { [] }

      context 'when all_test_file_paths exist' do
        let(:all_test_file_paths) { ['a_spec.rb'] }
        let(:logger) { double }

        before do
          described_class.class_variable_set(:@@used_seed, used_seed)

          expect(KnapsackPro).to receive(:logger).twice.and_return(logger)

          expect(KnapsackPro::Adapters::RSpecAdapter).to receive(:verify_bind_method_called)

          expect(KnapsackPro::Formatters::RSpecQueueSummaryFormatter).to receive(:print_summary)
          expect(KnapsackPro::Formatters::RSpecQueueProfileFormatterExtension).to receive(:print_summary)

          expect(KnapsackPro::Hooks::Queue).to receive(:call_after_queue)
          expect(KnapsackPro::Report).to receive(:save_node_queue_to_api)

          expect(logger).to receive(:info)
            .with('To retry all the tests assigned to this CI node, please run the following command on your machine:')
          expect(logger).to receive(:info).with(logged_rspec_command_matcher)
        end

        context 'when @@used_seed has been set' do
          let(:used_seed) { '8333' }
          let(:logged_rspec_command_matcher) { /#{args.join(' ')} --seed #{used_seed} \"a_spec.rb"/ }

          it do
            expect(subject).to eq({
              status: :completed,
              exitstatus: exitstatus,
            })
          end
        end

        context 'when @@used_seed has not been set' do
          let(:used_seed) { nil }
          let(:logged_rspec_command_matcher) { /#{args.join(' ')} \"a_spec.rb"/ }

          it do
            expect(subject).to eq({
              status: :completed,
              exitstatus: exitstatus,
            })
          end
        end
      end

      context "when all_test_file_paths don't exist" do
        let(:all_test_file_paths) { [] }

        it do
          expect(KnapsackPro::Hooks::Queue).to receive(:call_after_queue)
          expect(KnapsackPro::Report).to receive(:save_node_queue_to_api)
          expect(KnapsackPro).to_not receive(:logger)

          expect(subject).to eq({
            status: :completed,
            exitstatus: exitstatus,
          })
        end
      end
    end
  end
end
