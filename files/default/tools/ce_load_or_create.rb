class Chef
  class Environment
    def self.load_or_create(environment_name)
      begin
        env = Chef::Environment.load(environment_name)
      rescue Net::HTTPServerException => e
        raise e unless e.response.code == "404"
        env = Chef::Environment.new
        env.name environment_name
        env.description environment_name
        env.save
        env
      end
    end
  end
end

