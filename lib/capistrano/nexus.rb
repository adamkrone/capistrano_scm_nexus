load File.expand_path('../tasks/nexus.rake', __FILE__)
require 'capistrano/scm'
require 'net/http'
require 'nexus_cli'

class Capistrano::Nexus < Capistrano::SCM
  module DefaultStrategy
    def nexus_config
      nil
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

    def test
      test! " [ -d #{repo_path} ] "
    end

    def check
      remote.get_artifact_info(artifact_source)
    end

    def download
      @_pulled_artifact = remote.pull_artifact(artifact_source)
    end

    def file_name
      @_pulled_artifact.fetch(:file_name, nil)
    end

    def file_path
      @_pulled_artifact.fetch(:file_path, nil)
    end

    def unzip_dir
      "#{fetch(:nexus_artifact_name)}-#{fetch(:nexus_artifact_version)}"
    end

    def release
      context.execute :unzip, file_name, '-d', repo_path
      context.execute :mv, File.join(unzip_dir, '*'), fetch(:release_path)
    end

    def cleanup
      if test! " [ -f #{File.join(repo_path, file_name)} ] "
        context.execute :rm, file_name
      end

      if test! " [ -d #{File.join(repo_path, unzip_dir)} ] "
        context.execute :rm, '-rf', unzip_dir
      end

      File.delete(file_path)
    end

    def fetch_revision
      fetch(:nexus_artifact_version)
    end
  end
end
