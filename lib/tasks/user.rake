require 'securerandom'

namespace :user do
  desc 'Create an admin user using the console'
  task :create_admin => :environment do
    email = "admin@ad.min"
    password = SecureRandom.hex(6).to_s
    
    if User.where(email: email).count > 0
      abort("Default admin user does already exist.")
    end
    
    indi = Individual.create(type: "Person", label: "Admin")
    u = User.create(email: email, password: password, individual_id: indi.id, role: "admin")
    puts "User created with email #{email} and password #{password}"
  end
end