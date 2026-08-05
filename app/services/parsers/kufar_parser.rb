module Parsers
  class KufarParser

    def self.parse(url)
      new.parse(url)
    end

    def parse(url)
      doc = fetch_page(url)

      xpath_for_elements = if url.include? 'https://re.kufar.by/l/minskij-rajon/snyat/dom/'
                             '//a[starts-with(@href, "https://re.kufar.by/vi/minskij-rajon/snyat/dom/")]'
                           elsif url.include? 'https://re.kufar.by/vi/minsk/snyat/dom/'
                             '//a[starts-with(@href, "https://re.kufar.by/vi/minsk/snyat/dom/")]'
                           end

      # 1. Находим все ссылки-карточки (они же являются контейнерами для данных)
      ad_elements = doc.xpath(xpath_for_elements)

      ad_elements.each do |ad_link|
        href = ad_link['href']
        href_cleaned = href&.split('?').first

        next unless href

        # 2. Извлекаем external_id из URL (число после /dom/)
        external_id = href.match(%r{/dom/(\d+)})&.captures&.first
        next unless external_id

        # 3. Цена (удаляем все не-цифры, приводим к целому)
        price_node = ad_link.at_xpath('./div[2]/div[1]/div[1]/span')
        price = price_node&.text&.strip&.gsub(/[^\d]/, '')&.to_i

        # 4. Адрес
        address_node = ad_link.at_xpath('./div[2]/div[1]/div[2]/div[2]/span')
        address = address_node&.text&.strip

        # 5. Описание (текст объявления)
        description_node = ad_link.at_xpath('./div[2]/p')
        description = description_node&.text&.strip

        # 6. Фотографии – собираем все <img> внутри блока с фотографиями
        #    (используем относительный поиск: ищем все img внутри первого div)
        photo_nodes = ad_link.xpath('./div[1]//img')
        photos = photo_nodes.map { |img| img['src'] }.compact

        # 7. Заголовок – можно взять из описания или сгенерировать
        title = "Объявление #{external_id}"

        ad_attrs = {
          external_id: external_id,
          site: 'kufar',
          url: href_cleaned || href,
          title: title,
          price: price,
          address: address,
          description: description,
          published_at: Time.current,
          photos: photos
        }

        save_ad(ad_attrs)
      end
    end

    private

    def fetch_page(url)
      response = Faraday.get(url)
      Nokogiri::HTML(response.body)
    end

    # общий метод сохранения объявления
    def save_ad(attributes)
      ad = Ad.find_or_initialize_by(
        site: 'kufar',
        external_id: attributes[:external_id]
      )

      if ad.new_record?
        ad.assign_attributes(attributes)
        if ad.valid?
          ad.save!
          notify_telegram(ad)
        end
      else
        unless price_range(ad).include?(attributes[:price])
          old_price = ad.price

          ad.assign_attributes(attributes)
          if ad.valid?
            ad.save!
            notify_telegram(ad, old_price:)
          end
        end
      end
    end

    def price_range(ad)
      (ad.price - 135..ad.price + 135)
    end

    def notify_telegram(ad, old_price: false)
      Telegram::TelegramNotifier.notify_new_ad(ad, old_price:)
    end
  end
end
