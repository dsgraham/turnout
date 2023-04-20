require 'turnout'

namespace :maintenance do
  desc 'Enable the maintenance mode page ("reason", "allowed_paths", "allowed_ips" and "response_code" can be passed as environment variables)'
  rule /\Amaintenance:(.*:|)start\Z/ do |task|
    invoke_environment

    maint_file = Turnout::MaintenanceFile.default
    maint_file.import_env_vars(ENV)
    maint_file.write

    puts "Created #{maint_file.key}"
    puts "Run `rake #{task.name.gsub(/\:start/, ':end')}` to stop maintenance mode"
  end

  desc 'Disable the maintenance mode page'
  rule /\Amaintenance:(.*:|)end\Z/ do |task|
    invoke_environment

    maint_file = Turnout::MaintenanceFile.default

    if maint_file.delete
      puts "Deleted #{maint_file.key}"
    else
      fail 'Could not find a maintenance file to delete'
    end
  end

  def invoke_environment
    if Rake::Task.task_defined? 'environment'
      Rake::Task['environment'].invoke
    end
  end
end
