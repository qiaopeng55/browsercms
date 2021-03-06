When /^fill valid fields for a new user named "([^"]*)"$/ do |username|
  fill_in "Username", :with=>username
  fill_in "Email", :with=>"#{username}@example.com"
  fill_in "First Name", :with=>"Mr."
  fill_in "Last Name", :with=>"Blank"
  fill_in "Password", :with=>"abc123"
  fill_in "Confirm Password", :with=>"abc123"
  click_on "Save"
end
Given /^the following content editor exists:$/ do |table|
    table.hashes.each do |row|
      row['login'] = row.delete('username')
      Factory(:content_editor, row)
    end
end
When /^I login as:$/ do |table|
  user = table.hashes.first
  visit '/cms/login'
  fill_in 'login', :with => user['login']
  fill_in 'password', :with => user['password']
  click_button 'LOGIN'
end