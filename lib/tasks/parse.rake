namespace :parse do
  desc "Запуск всех парсеров"
  task all: :environment do

    urls = ENV['PARSER_URLS_FOR_RENT']&.split(',') || []
    urls_for_sell = ENV['PARSER_URLS_FOR_SELL']&.split(',') || []

    urls.each do |url|
      if url.include?('realt')
        parser = Parsers::RealtParser
      elsif url.include?('kufar')
        parser = Parsers::KufarParser
      else
        Rails.logger.warn "Неизвестный сайт: #{url}"
        next
      end

      begin
        Rails.logger.info "Запуск парсера для #{url}"
        parser.parse(url)
        Rails.logger.info "Парсинг #{url} завершён"
      rescue => e
        Rails.logger.error "Ошибка при парсинге #{url}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
    end

    urls_for_sell.each do |url|
      if url.include?('realt')
        parser = Parsers::RealtParser
      elsif url.include?('kufar')
        parser = Parsers::KufarParser
      else
        Rails.logger.warn "Неизвестный сайт: #{url}"
        next
      end

      begin
        Rails.logger.info "Запуск парсера для продажи #{url}"
        parser.parse(url, for_sell: true)
        Rails.logger.info "Парсинг по продаже #{url} завершён"
      rescue => e
        Rails.logger.error "Ошибка при парсинге по продаже #{url}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
    end
  end
end
