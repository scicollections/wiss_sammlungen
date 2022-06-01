module Dereferencable
  module ClassMethods
    def dereference_mapping
      @dereference_mapping
    end
    
    def add_dereferencer name, dereferencer_class,*args
      @dereference_mapping ||= {}
      @dereference_mapping[name] = dereferencer_class
    end
    
    def get_dereferencer name
      @dereference_mapping[name] || nil
    end
    
  end
  
  module InstanceMethods
    def dereferences? url
      self.class.dereference_mapping.each do |name,dereferencer_klass|        
          return name if dereferencer_klass.dereferences? url
      end
      return false
    end
    
    def dereference url
      name = dereferences?(url)
      return false unless name
      
      begin 
        data = Rails.cache.fetch("/reference_vocabs/cache_data/#{url}", :expires_in => 14.days) do
          self.class.get_dereferencer(name).dereference(url)
        end
        return data
      rescue 
        return false
      end
    end
    
  end
  
end