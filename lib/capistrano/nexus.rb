load File.expand_path('../tasks/nexus.rake', __FILE__)
require 'capistrano/scm'
require 'net/http'
require 'nexus_cli'

class Capistrano::Nexus < Capistrano::SCM
  module DefaultStrategy
    def nexus_config
      {
        'url' => fetch(:nexus_url),
        'repository' => fetch(:nexus_repository),
        'username' => fetch(:nexus_username),
        'password' => fetch(:nexus_password)
      }
    end

    def remote
      @_remote ||= NexusCli::RemoteFactory.create(nexus_config, nexus_ssl_verify)
    end

    def nexus_ssl_verify
      @_ssl_verify ||= fetch(:nexus_ssl_verify, false)
    end

    def artifact_source
      @_artifact_source ||= [fetch(:nexus_group_id),
                             fetch(:nexus_artifact_name),
                             fetch(:nexus_artifact_ext),
                             fetch(:nexus_artifact_classifier),
                             fetch(:nexus_artifact_version)].join(':')
    end

    def artifact_filename
      "#{fetch(:nexus_artifact_name)}-#{fetch(:nexus_artifact_version)}-#{fetch(:nexus_artifact_classifier)}"
    end

    def artifact_filename_without_classifier
      artifact_filename.gsub("-#{fetch(:nexus_artifact_classifier)}", '')
    end

    def artifact_filename_with_ext
      "#{artifact_filename}.#{fetch(:nexus_artifact_ext)}"
    end

    def test
      test! " [ -d #{repo_path} ] "
    end

    def check
      remote.get_artifact_info(artifact_source)
    end

    def download
      remote.pull_artifact(artifact_source)
    end

    def release
      context.execute :unzip, artifact_filename_with_ext, '-d', repo_path
      context.execute :mv, File.join(artifact_filename_without_classifier, '*'), fetch(:release_path)
    end

    def cleanup
      if test! " [ -f #{File.join(repo_path, artifact_filename_with_ext)} ] "
        context.execute :rm, artifact_filename_with_ext
      end

      if test! " [ -d #{File.join(repo_path, artifact_filename)} ] "
        context.execute :rm, artifact_filename
      end

      local_file = File.expand_path(artifact_filename_with_ext)

      run_locally do
        execute :rm, local_file
      end
    end

    def fetch_revision
      fetch(:nexus_artifact_version)
    end
  end
end
