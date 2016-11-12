class Check < ApplicationRecord

  # #############################################################
  # Associations

  has_many :positions
  belongs_to :user

  has_many :pays
  has_many :debtors, :through => :pays, :source => :user

  # #############################################################
  # Validations
  
  validates :title, format: { with: /\A[a-zA-Z0-9а-яА-ЯёЁ\s]+\z/, message: "only allows letters" }

  # #############################################################
  # Callbacks

  # #############################################################
  # Uploaders

  mount_uploader :image, ImageUploader
end
