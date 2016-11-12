class Pay < ApplicationRecord

  # #############################################################
  # Associations

  belongs_to :user
  belongs_to :check

  # #############################################################
  # Validations

  validates_uniqueness_of :user_id, :scope => :check_id
end
