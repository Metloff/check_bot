require 'telegram/bot'

class Bot::MessageParser

  def initialize(message, user)
    @message = message
    @user = user
    @token = Rails.application.secrets.bot_token
    @url = Rails.application.secrets.domen
    @api = ::Telegram::Bot::Api.new(@token)
    
    # return if @message.blank?
  end

  def run
    if self.text == '/start' || self.text == 'В начало'
      self.start
    else
      # begin
        self.send(command)
      # rescue
      #   self.send_message('Что-то пошло не так, попробуйте еще раз :)')
      # end
    end
  end

  # #############################################################
  # Methods
  def start
    @user.on_start!

    self.send_message('Выберите желаемую опцию', { reply_markup: self.running_answers })
    @user.run!
  end

  def running
    case self.text
    when 'Создать чек'
      self.send_message('Введите название чека')
      @user.create_check!
    when 'Мои чеки'
      if @user.checks.blank?
        self.send_message("У Вас нет созданных чеков", { reply_markup: self.running_answers })
        return
      end
      self.send_message("Выберите тип отображения чеков: Полный, Средний, Короткий", { reply_markup: size_answers })
      @user.show_checks!
    when 'Мои долги' 
      message = self.show_debts
      message << "\nНажмите на номер чека, чтобы пометить долг как оплаченный"
      self.send_message(message, { parse_mode: 'Markdown', reply_markup: self.start_answers })
      @user.make_debt_completed!
    when 'Добавить долг'
      self.send_message('Введите номер чека. Например: 17')
      @user.prepare_for_adding_debt!
    else
      self.send_message('Вы ввели неверное значение. Выберите пожалуйста желаемое действие, используя клавиатуру ниже.', { reply_markup: self.running_answers })
    end
  end

  ######## Ветка создания чека
  def creating_check
    if self.text.blank?
      self.error_1
      return
    end

    check = Check.new(title: self.text, user_id: @user.id)
    unless check.save
      return self.error_1
    end

    self.set_check(check)

    self.send_message('Хотите прикрепить фотографию чека?', { reply_markup: self.yes_no_answers })
    @user.question_about_photo! 
  end

  def need_photo
    if text.present? && text == 'Да'
      self.send_message('Пришлите фото в чат')
      @user.attaching_photo!
    elsif text.present? && text == 'Нет'
      # self.send_message('Теперь займемся созданием позиций из Вашего чека!) Для этого пришлите название блюда, количество человек, которые участвовали в поедании, цену блюда, в формате *название;кол-во человек;цена* . Пример: *пивной сет;4;750*', { parse_mode: 'Markdown' })
      self.send_message("Теперь займемся созданием позиций из Вашего чека!)\nДля этого пришлите название блюда, количество человек, которые участвовали в поедании и цену блюда, разделяя их между собой знаком '*;*', вот так:\n*название;кол-во человек;цена* \nПример: *пивной сет;4;750*", { parse_mode: 'Markdown' })
      @user.creating_position!
    end
  end

  def attach_photo
    # if current_check.blank?
    #   # возвращаем на место выбора чека (перекидываем в ветку редактирования чека)
    # end

    if self.photos.present?
      file_id = photos.sort{ |x,y| y['file_size'] <=> x['file_size'] }.first['file_id']
      file = self.get_file(file_id)

      url = "https://api.telegram.org/file/bot#{ @token }/#{ file['result']['file_path'] }"
      self.current_check.update_attributes(remote_image_url: url)

      self.send_message("Теперь займемся созданием позиций из Вашего чека!)\nДля этого пришлите название блюда, количество человек, которые участвовали в поедании и цену блюда, разделяя их между собой знаком '*;*', вот так:\n*название;кол-во человек;цена* \nПример: *пивной сет;4;750*", { parse_mode: 'Markdown' })
      @user.creating_position!
    else
      self.send_message('Пришлите фото в чат')
    end
  end

  def create_position
    if self.text.blank?
      self.error_1 
      return
    end

    title, number_of_people, price = self.text.split(';')
    position = current_check.positions.new(title: title.strip, number_of_people: number_of_people.strip, price: price)

    unless position.save
      self.error_1 
      return
    end

    self.send_message('Хотите добавить еще позицию?', { reply_markup: self.yes_no_answers })
    @user.question_about_position! 
  end

  def need_create_position
    if self.text.blank? || ['Да', 'Нет'].exclude?(self.text)
      self.error_2(reply_markup: self.yes_no_answers)
      return
    end

    if self.text == 'Да'
      self.send_message("Пришлите название блюда, количество человек, которые участвовали в поедании, цену блюда, в формате \n*название;кол-во человек;цена*  \nПример: *пивной сет;4;750*", { parse_mode: 'Markdown' })
      @user.creating_position!
    elsif self.text == 'Нет'
      self.send_message("Чек №#{ current_check.id } успешно создан! Теперь вы можете отправить этот номер друзьям, чтобы они отметили, за что именно они должны деньги.", { reply_markup: self.start_answers })
      @user.on_start!
    end
  end

  ######## Ветка создания долга
  def show_check_for_debt
    message = self.show_check(self.text, 'full')
    return if message.blank?

    message << "\n Это тот чек?"

    self.send_message(message, { parse_mode: 'Markdown', reply_markup: self.yes_no_answers })
    @user.check_the_check_info!
  end

  def checking_check
    if self.text.blank? || ['Да', 'Нет'].exclude?(self.text)
      return self.error_2(reply_markup: self.yes_no_answers)
    end

    if self.text == 'Да'
      if self.current_check.positions.blank?
        self.send_message("К сожалению у данного чека нет позиций, поэтому вы не можете создать долг.\nВы можете ввести номер другого чека или вернуться на стартовый экран", { reply_markup: self.start_answers })
        @user.prepare_for_adding_debt!
        return
      end

      pay = Pay.find_by(user_id: @user.id, check_id: self.current_check.id)
      if pay.present?
        self.send_message("Вы уже создали долг по этому чеку.\nОн равен: *#{ pay.debt }* \nВы можете ввести номер другого чека или вернуться на стартовый экран", { parse_mode: 'Markdown', reply_markup: self.start_answers })
        @user.prepare_for_adding_debt!
        return
      end

      self.send_message('Укажите номера позиций, которые Вы ели, в формате: *1;7;9*', { parse_mode: 'Markdown' })
      @user.calculation_debt!
    elsif self.text == 'Нет'
      self.send_message('Тогда попробуйте ввести номер чека еще раз. Например: 17')
      @user.prepare_for_adding_debt!
    end 
  end

  def debt_payment
    if self.text.blank?
      self.error_1
      return
    end

    position_custom_ids = self.text.split(';').map{|i| i.strip }.uniq
    debt = BigDecimal.new(0)

    position_custom_ids.each do |custom_id|
      custom_id = custom_id.try(:to_i)
      position = self.current_check.positions.find_by(custom_id: custom_id)
      next if position.blank?

      @user.positions << position

      debt += position.price / position.number_of_people
    end

    Pay.create!(user_id: @user.id, check_id: self.current_check.id, debt: debt)

    self.send_message("Чек №#{ self.current_check.id} - #{ self.current_check.title }. \n Ваш долг: *#{ debt }*", { parse_mode: 'Markdown', reply_markup: self.start_answers })
  end

  ######## Ветка показа существующих чеков
  def show_existing_checks
    if self.text.blank? || ['Полный', 'Средний', 'Короткий'].exclude?(text)
      self.error_2(reply_markup: self.running_answers)
    end

    case self.text
    when 'Полный'   then command = 'full'
    when 'Средний'  then command = 'middle'
    when 'Короткий' then command = 'short'
    end

    message = ''
    @user.checks.each do |check|
      message << self.send("create_message_#{ command }", check)
      message << "---------------------- \n\n"
    end
    message << "Вы можете выбрать любой чек, для дополнительных действий с ним. Для этого введите его номер."
    self.send_message(message, { parse_mode: 'Markdown'})
    @user.check_preview!
  end

  ######## Ветка показа/редактирования чека
  def check_preview
    message = self.show_check(self.text, 'middle')
    return if message.blank?

    if @user.id != self.current_check.user_id
      self.send_message(message, { parse_mode: 'Markdown', reply_markup: self.protect_check_answers})
      @user.choose_protect_check_action!
      return
    end

    self.send_message(message, { parse_mode: 'Markdown', reply_markup: self.my_check_answers})
    @user.choose_my_check_action!
  end

  def choosing_my_check_action
    if self.text.blank? || ['Показать фотографию', 'Изменить', 'Пометить как оплаченный', 'Посмотреть должников'].exclude?(self.text)
      self.error_2(reply_markup: self.my_check_answers)
      return
    end

    case self.text
    when 'Показать фотографию'
      self.show_photo(reply_markup: self.my_check_answers)
    when 'Изменить'
      self.send_message('Выберите, что именно вы хотите изменить', { reply_markup: self.edit_check_answers })
      @user.edit_check!
    when 'Пометить как оплаченный'
      ## !
      self.current_check.update_attributes(is_complete: true)
      message = self.show_check(self.current_check.id, 'middle')
      self.send_message("Чек успешно обновлен \n\n #{ message }", { reply_markup: self.my_check_answers, parse_mode: 'Markdown' })
    when 'Посмотреть должников'
      ## !
      message = self.show_debtors
      self.send_message(message, { reply_markup: self.my_check_answers, parse_mode: 'Markdown' })
    end
  end

  def choosing_protect_check_action
    if self.text.blank? || ['Показать фотографию', 'Добавить долг'].exclude?(self.text)
      self.error_2(reply_markup: self.protect_check_answers)
      return
    end

    case self.text
    when 'Показать фотографию'
      self.show_photo(reply_markup: self.protect_check_answers)
    when 'Добавить долг'
      self.send_message('Укажите номера позиций, которые Вы ели, в формате: *1;7;9*', { parse_mode: 'Markdown'})
      @user.calculation_debt!
    end
  end

  def editing_check
    if self.text.blank? || ['Название чека', 'Позицию', 'Фотографию', 'Назад'].exclude?(self.text)
      self.error_2(reply_markup: self.edit_check_answers)
      return
    end

    case self.text
    when 'Название чека'
      self.send_message('Введите новое название чека')
      @user.edit_check_title!
    when 'Позицию'
      self.send_message('Введите номер позиции и новые данные. Разделяйте все знаком ";". Пример: Вы хотите изменить позицию номер 2. Вы вводите: номер позиции; название блюда; количество человек, которые участвовали в поедании; цену блюда (2;индейка;4;1350)')
      @user.edit_position!
    when 'Фотографию'
      self.send_message('Пришлите новую фотографию')
      @user.edit_check_photo!
    when 'Назад'
      self.send_message('Выберите действие', { reply_markup: self.my_check_answers, parse_mode: 'Markdown' })
      @user.choose_my_check_action!
    end
  end

  def editing_check_title
    if self.text.blank?
      self.error_1 
      return
    end

    unless self.current_check.update_attributes(title: self.text)
      self.error_1
      return
    end

    message = self.show_check(self.current_check.id, 'middle')
    self.send_message("Название чека успешно обновленно \n\n #{ message }", { reply_markup: self.my_check_answers, parse_mode: 'Markdown' })
    @user.edit_rollback!
  end

  def editing_position
    if self.text.blank?
      self.error_1 
      return
    end

    custom_id, title, number_of_people, price = self.text.split(';')
    position = self.current_check.positions.find_by(custom_id: custom_id)
    return self.error_1 if position.blank?

    unless position.update_attributes(title: title, number_of_people: number_of_people, price: price)
      self.error_1
      return
    end

    message = self.show_check(self.current_check.id, 'middle')
    self.send_message("Позиция успешно обновлена \n\n #{ message }", { reply_markup: self.my_check_answers, parse_mode: 'Markdown' })
    @user.edit_rollback!
  end

  def editing_check_photo
    if self.photos.blank?
      self.send_message('Пришлите фото в чат')
      return
    end
    
    file_id = photos.sort{ |x,y| y['file_size'] <=> x['file_size'] }.first['file_id']
    file = self.get_file(file_id)

    url = "https://api.telegram.org/file/bot#{ @token }/#{ file['result']['file_path'] }"
    self.current_check.update_attributes(remote_image_url: url)

    message = self.show_check(self.current_check.id, 'middle')
    self.send_message("Фото успешно обновленно \n\n #{ message }", { reply_markup: self.my_check_answers, parse_mode: 'Markdown' })
    @user.edit_rollback!
  end

  ######## Ветка мои долги
  def debt_completed
    return self.error_1 if self.text.blank?
    id = self.text.slice(1..-1)

    if id.blank? || id.to_i == 0
      return self.error_1
    end 

    debt = Pay.find_by(check_id: id.to_i, user_id: @user.id)

    unless debt.update_attributes(is_complete: true)
      return self.error_1
    end

    self.send_message("Долг успешно обновлен", { reply_markup: self.my_debdts_answers })
    @user.run!
  end


  # #############################################################
  # Helpers

  def command
    @command ||= @user.aasm_state
  end

  def text
    @text ||= @message[:message][:text]
  end

  def photos
    @photos ||= @message[:message][:photo]
  end

  def send_message(body, options={})
    @api.call('sendMessage', chat_id: @user.telegram_id, text: body, reply_markup: options[:reply_markup], parse_mode: options[:parse_mode])
  end

  def send_photo(body, options={})
    @api.call('sendPhoto', chat_id: @user.telegram_id, photo: body, reply_markup: options[:reply_markup])
  end

  def get_file(file_id)
    @api.call('getFile', file_id: file_id)
  end

  def current_check
    return @check if defined?(@check)

    check_id = $redis.get("#{ @user.telegram_id }_check_id")
    return nil if check_id.blank?

    @check = Check.find(check_id.to_i)
  end

  def set_check(check)
    $redis.set("#{ @user.telegram_id }_check_id", "#{ check.id }")
  end

  def start_answers
    @answers ||= Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: [['В начало']], one_time_keyboard: true)
  end

  def running_answers
    @answers ||= Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: [['Создать чек', 'Добавить долг'], ['Мои долги', 'Мои чеки']], one_time_keyboard: true)
  end

  def my_debdts_answers
    @answers ||= Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: [['Мои долги'], ['В начало']], one_time_keyboard: true)
  end

  def yes_no_answers
    @answers ||= Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: [['Да'], ['Нет']], one_time_keyboard: true)
  end

  def size_answers
    @answers ||= Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: [['Полный'], ['Средний'], ['Короткий']], one_time_keyboard: true)
  end

  def protect_check_answers
    @answers ||= Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: [['Показать фотографию'],['Добавить долг', 'В начало']], one_time_keyboard: true)
  end

  def my_check_answers
    @answers ||= Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: [['Показать фотографию', 'Изменить'], ['Пометить как оплаченный', 'Посмотреть должников', 'В начало']], one_time_keyboard: true)
  end

  def edit_check_answers
    @answers ||= Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: [['Название чека', 'Фотографию'], ['Позицию', 'Назад']], one_time_keyboard: true)
  end

  def error_1
    self.send_message('Данные введены не корректно. Попробуйте пожалуйста еще раз')
  end

  def error_2(markup)
    self.send_message('Вы ввели неверное значение. Выберите пожалуйста ответ, используя клавиатуру ниже.',  { reply_markup: markup[:reply_markup] })
  end

  def show_check(id, size)
    if id.blank? || id.to_i <= 0
      self.send_message('Что то пошло не так. Введите номер чека еще раз. Например: 17')
      return nil
    end
    
    check = Check.find_by(id: id.to_i)

    if check.blank?
      self.send_message('Такого чека не существует. Введите номер чека еще раз. Например: 17')
      return nil
    end

    self.set_check(check)
    message = self.send("create_message_#{size}", check)
  end

  def create_message_full(check)
    check.is_complete ? compl = '✅' : compl = '🔴'
    message = "#{ compl } *Чек №#{ check.id }* - #{ check.title } от #{ check.created_at.strftime('%d:%m:%Y') }.\n"
    return message if check.positions.blank?

    check.positions.each do |p|
      message << "*Позиция № #{ p.custom_id }*.\n _Название:_ #{ p.title }.\n _Кол-во человек:_ #{ p.number_of_people }.\n _Цена:_ #{ p.price }. \n"
    end
    message
  end

  def create_message_middle(check)
    check.is_complete ? compl = '✅' : compl = '🔴'
    message = "#{ compl } *Чек №#{ check.id }* - #{ check.title } от #{ check.created_at.strftime('%d:%m:%Y') }.\n"
    return message if check.positions.blank?

    check.positions.each do |p|
      message << "*№ #{ p.custom_id }* ------------------ \n"
      message << "#{ p.title } | 👫: #{ p.number_of_people } | ₽: #{ p.price } \n\n"
    end
    message
  end

  def create_message_short(check)
    check.is_complete ? compl = '✅' : compl = '🔴'
    message = "#{ compl } *Чек №#{ check.id }* - #{ check.title } от #{ check.created_at.strftime('%d:%m:%Y') }.\n"
  end

  def show_photo(options)
    if self.current_check.image.blank?
      self.send_message("К данному чеку фотография не прикреплена.\nВы можете ее прикрепить, перейдя Мои чеки -> Выбор конекретного чека -> Изменить -> Фотографию", { reply_markup: options[:reply_markup] })
      return
    end

    self.send_photo("#{ @url }#{ self.current_check.image.url }", reply_markup: options[:reply_markup])
  end

  def show_debtors
    return 'Должники не найдены' if self.current_check.debtors.blank?
    message = ''
    self.current_check.debtors.each do |debtor|
      message << "#{ debtor.first_name } #{ debtor.last_name }:  "
      message << "Долг: #{ debtor.pays.find_by(check_id: self.current_check.id).debt }\n"
    end
    message
  end

  def show_debts
    message = ''
    @user.pays.each do |pay|
      pay.is_complete ? compl = '✅' : compl = '🔴'
      message << "Чек номер: /#{ pay.check_id } - долг: #{ pay.debt } | #{ compl } \n"
    end
    message
  end
end

## Показывать весь чек (показ чека вынести в отдельный метод)
## Создать чек | Показать чек | Мои чеки | Добавить долг | Мои долги
## Разбить действия по методам (Действия над чеками (index, put, create...) и долгами.)

## Продумать падение / недоступность редиса
## Сделать невозможность добавления двух долгов сразу на один чек                                             ✅
## Зарпетить при создании долга указывать одну и ту же позицию два раза                                       ✅
## При просмотре чеков, можно посмотреть фотографию. Если ее нет, необходимо дать возможность ее прекрепить.  ✅
## В протектед ансверс необходимо сделать кнопку Назад                                                        ✅
## При добавлении долга предлагается указать номера позиций которые ты ел. Может быть такая ситуация что у чека нет позиций. ✅
# Надо сделать на это првоерку.

## Обрезать долг до 2 знаков после запятой
## При создании долга можно указать несуществующую позицию
## Проверку на существует чек или нет (когда вводишь номер чека в моих чеках)