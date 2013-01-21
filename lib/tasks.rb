namespace :shared do
	task :make_shared_dir do
		run "if [ ! -d #{shared_path}/files ]; then mkdir #{shared_path}/files; fi"
	end
	task :make_symlinks do
		run "if [ ! -h #{release_path}/shared ]; then ln -s #{shared_path}/files/ #{release_path}/shared; fi"
		run "for p in `find -L #{release_path} -type l`; do t=`readlink $p | grep -o 'shared/.*$'`; mkdir -p #{release_path}/$t;done"
	end
	desc "Changes symlink paths from absolute to relative"
	task :resymlink do
		path_to = relative_path(latest_release, File.join(shared_path,'files/'))
		run "cd #{latest_release}; rm -r shared && ln -s #{path_to} shared"
		run "cd #{deploy_to}; rm -r current; ln -s releases/#{release_name} current"

	end
end

namespace :git do
	desc "Updates git submodule tags"
	task :submodule_tags do
		run "if [ -d #{shared_path}/cached-copy/ ]; then cd #{shared_path}/cached-copy/ && git submodule foreach --recursive git fetch origin --tags; fi"
	end
end

namespace :db do
	desc "Syncs the staging database (and uploads) from production"
	task :sync, :roles => :web	do
		if stage != :staging then
			puts "[ERROR] You must run db:sync from staging with cap staging db:sync"
		else
			puts "Hang on... this might take a while."
			random = rand( 10 ** 5 ).to_s.rjust( 5, '0' )
			p = wpdb[ :production ]
			s = wpdb[ :staging ]
			puts "db:sync"
			puts stage
			system "mysqldump -u #{p[:user]} --result-file=/tmp/wpstack-#{random}.sql -h #{p[:host]} -p#{p[:password]} #{p[:name]}"
			system "mysql -u #{s[:user]} -h #{s[:host]} -p#{s[:password]} #{s[:name]} < /tmp/wpstack-#{random}.sql && rm /tmp/wpstack-#{random}.sql"
			puts "Database synced to staging"
			# memcached.restart
			puts "Memcached flushed"
			# Now to copy files
			find_servers( :roles => :web ).each do |server|
				system "rsync -avz --delete #{production_deploy_to}/shared/files/ #{server}:#{shared_path}/files/"
			end
		end
	end
	desc "Sets the database credentials (and other settings) in wp-config.php"
	task :make_config do
		staging_domain ||= ''
		{:'%%WP_STAGING_DOMAIN%%' => staging_domain, :'%%WP_STAGE%%' => stage, :'%%DB_NAME%%' => wpdb[stage][:name], :'%%DB_USER%%' => wpdb[stage][:user], :'%%DB_PASSWORD%%' => wpdb[stage][:password], :'%%DB_HOST%%' => wpdb[stage][:host]}.each do |k,v|
			run "sed -i '' 's/#{k}/#{v}/' #{release_path}/wp-config.php", :roles => :web
		end
	end
end
