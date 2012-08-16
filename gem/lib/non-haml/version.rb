module NonHaml
  unless const_defined?('VERSION')
    VERSION = "1.0.1"
  end

  def self.version
    VERSION
  end
end
