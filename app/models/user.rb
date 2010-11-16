require 'digest/sha1'
class User < ActiveRecord::Base
  has_and_belongs_to_many :groups

  has_and_belongs_to_many :course_instances_assistant, {:class_name => 'CourseInstance', :join_table => 'course_instances_students', :order => :course_instance_id}
  has_and_belongs_to_many :course_instances_student, {:class_name => 'CourseInstance', :join_table => 'assistants_course_instances', :order => :course_instance_id}
  has_and_belongs_to_many :courses_teacher, {:class_name => 'Course', :join_table => 'courses_teachers', :order => :course_id}

  has_many :reviews, :order => 'id'               # reviews as a grader

  # Virtual attribute for the unencrypted password
  attr_accessor :password

  validates_uniqueness_of :studentnumber, :allow_nil => true
  validates_uniqueness_of :login, :allow_nil => true
  validates_confirmation_of :password, :if => :password

  before_save :encrypt_password

  # prevents a user from submitting a crafted form that bypasses activation
  # anything else you want your user to change should be added here.
  attr_accessible :studentnumber, :firstname, :lastname, :email, :password, :password_confirmation

  # Authenticates a user by their login name and unencrypted password.  Returns the user or nil.
  def self.authenticate(studentnumber, password)
    logger.info("Athenticating with password '#{password}'")
    u = find_by_studentnumber(studentnumber)

    if !u
      logger.info("Unknown user #{studentnumber} tried to log in")
      return nil
    end

    if u.authenticated?(password)
      logger.info("#{studentnumber} logged in with password.")
      return u
    else
      logger.info("#{studentnumber} tried to log in with an invalid password.")
      return nil
    end
  end

  # Encrypts some data with the salt.
  def self.encrypt(password, salt)
    
    hash = Digest::SHA1.hexdigest("--#{salt}--#{password}--")
    logger.debug("--#{salt}--#{password}-- => #{hash}")
    hash
  end

  # Encrypts the password with the user salt
  def encrypt(password)
    self.class.encrypt(password, salt)
  end

  def authenticated?(password)
    crypted_password == encrypt(password)
  end

  def remember_token?
    remember_token_expires_at && Time.now.utc < remember_token_expires_at
  end

  # These create and unset the fields required for remembering users between browser closes
  def remember_me
    remember_me_for 2.weeks
  end

  def remember_me_for(time)
    remember_me_until time.from_now.utc
  end

  def remember_me_until(time)
    self.remember_token_expires_at = time
    self.remember_token            = encrypt("#{email}--#{remember_token_expires_at}")
    save(false)
  end

  def forget_me
    self.remember_token_expires_at = nil
    self.remember_token            = nil
    save(false)
  end

  # Returns true if the user has just been activated.
  def recently_activated?
    @activated
  end

  def name
    "#{firstname} #{lastname}"
  end

  def is_admin?
    self.admin
  end

  def is_teacher?
    courses_teacher.size > 0
  end

  protected
    # before filter
    def encrypt_password
      self.salt = Digest::SHA1.hexdigest("--#{Time.now.to_s}--#{studentnumber}--") if new_record?

      return if password.blank?
      self.crypted_password = encrypt(password)
    end

    def password_required?
      crypted_password.blank? || !password.blank?
    end


end
