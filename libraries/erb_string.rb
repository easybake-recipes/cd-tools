require 'erubis'

class ErbString
  def self.do(string, binding)
    erb = Erubis::Eruby.new(string)
    if binding.kind_of?(Erubis::Context)
      erb.result(binding.to_hash)
    else
      erb.result(binding)
    end
  end
end
