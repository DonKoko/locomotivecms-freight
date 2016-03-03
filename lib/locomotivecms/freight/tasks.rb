module Locomotivecms
  module Freight
    class Tasks
      include Rake::DSL if defined? Rake::DSL

      def install_tasks
        load File.expand_path('../tasks.rake', __FILE__)
      end
    end
  end
end

Locomotivecms::Freight::Tasks.new.install_tasks

