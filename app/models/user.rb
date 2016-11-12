class User < ApplicationRecord

  # #############################################################
  # Associations

  has_many :checks

  has_many :pays
  has_many :debts, :through => :pays, :source => :check

  has_many :details
  has_many :positions, :through => :details

  # Юзер много чеков как овнер
  # Чеки много юзеров как должников

  # #############################################################
  # Validations
  
  validates_uniqueness_of :telegram_id

  # #############################################################
  # Callbacks


  include AASM

# Ветка создания чека                                         \/
# Ветка редактирования чека (подветка - создание позиций)
# Ветка прикрепления людей

  aasm do # default column: aasm_state
    state :start, :initial => true
    state :running
    state :creating_check
    state :need_photo
    state :attach_photo
    state :create_position
    state :need_create_position
    state :debt_completed

    state :show_check_for_debt
    state :checking_check
    state :debt_payment

    # state :choose_size
    state :show_existing_checks

    state :check_preview
    state :choosing_my_check_action
    state :choosing_protect_check_action
    state :editing_check
    state :editing_check_title
    state :editing_check_photo
    state :editing_position

    event :run do
      transitions :from => [:start, :debt_completed], :to => :running
    end

    ## Создание чека
    event :create_check do
      transitions :from => :running, :to => :creating_check
    end

    event :on_start do
      transitions :to => :start
    end

    event :question_about_photo do
      transitions :from => :creating_check, :to => :need_photo
    end

    event :attaching_photo do
      transitions :from => :need_photo, :to => :attach_photo
    end

    event :creating_position do
      transitions :from => [:attach_photo, :need_photo, :need_create_position], :to => :create_position
    end

    event :question_about_position do
      transitions :from => :create_position, :to => :need_create_position
    end

    ## Прикрепление людей
    event :prepare_for_adding_debt do
      transitions :from => [:running, :checking_check], :to => :show_check_for_debt
    end

    event :check_the_check_info do
      transitions :from => :show_check_for_debt, :to => :checking_check
    end

    event :calculation_debt do
      transitions :from => [:checking_check, :choosing_protect_check_action], :to => :debt_payment
    end

    ## Показ существующих чеков
    event :show_checks do
      transitions :from => :running, :to => :show_existing_checks
    end

    ## Показ/редактирование чека
    event :check_preview do
      transitions :from => [:running, :show_existing_checks], :to => :check_preview
    end

    event :choose_my_check_action do
      transitions :from => [:check_preview, :editing_check], :to => :choosing_my_check_action
    end

    event :choose_protect_check_action do
      transitions :from => :check_preview, :to => :choosing_protect_check_action
    end

    event :edit_check do
      transitions :from => :choosing_my_check_action, :to => :editing_check
    end

    event :edit_check_title do
      transitions :from => :editing_check, :to => :editing_check_title
    end

    event :edit_check_photo do
      transitions :from => :editing_check, :to => :editing_check_photo
    end

    event :edit_position do
      transitions :from => :editing_check, :to => :editing_position
    end

    event :edit_rollback do
      transitions :from => [:editing_position, :editing_check_photo, :editing_check_title], :to => :choosing_my_check_action
    end


    event :make_debt_completed do
      transitions :from => :running, :to => :debt_completed
    end
  end


  def self.user_processing(from)
    @user = User.find_by(telegram_id: from[:id]) || self.register_user(from)
  end

  def self.register_user(from)
    @user = User.new(telegram_id: from[:id])
    @user.update_attributes(first_name: from[:first_name], last_name: from[:last_name])
    @user
  end

  def allowed_command
    Command.where(state: self.state)
  end
end
