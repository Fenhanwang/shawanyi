require 'nokogiri'
require 'open-uri'
require 'json'
require 'pp'
require 'csv'
require 'pry-byebug'
require 'mongo'

Mongo::Logger.logger.level = ::Logger::INFO

class RealTimeXianStock

  def initialize(zhang_fu)
    @url = "http://eoddata.com/stocklist/NASDAQ/%s.htm"
    @char_array = ("A".."Z").to_a
    @stock_abb_array = []
    @zhang_fu = zhang_fu # 0.3
    @count = 0
    @client = Mongo::Client.new([ '127.0.0.1:27017' ], :database => 'real_time_stock')
    @db = @client.database
  end

  def biao_zhun_cha
  	i = 1
    crawl_stock_name
    
    @stock_abb_array.each_slice(20) do |arr|
    	threads = []
	    arr.each { |e|
	      # cal_stock_trend(e, 30, "Close")
	      # cal_stock_trend(e, 30, "Volume", 100)
	      puts i if i%1000 == 0  
	      threads << Thread.new(e){|ee|cal_protential_zuokong(ee, 30, @zhang_fu)}
	      i+=1
	    }
	    # sleep 5
	    threads.each(&:join)
    end
	end


  def crawl_stock_name
    @char_array.each { |e|
      current_url = @url % [e]
      page = Nokogiri::HTML(open(current_url))
      page.xpath("//div[@id='ctl00_cph1_divSymbols']/table/tr")[1..-1].each { |tr|
      tds = tr.elements
      @stock_abb_array << tds.first.content
      }
    }

    puts "Stock Size is #{@stock_abb_array.size}"
  end

  def loop_stock_array
    if @db.collection_names.size == 0
      crawl_stock_name
    end
    @stock_abb_array = @client[:stocks].find({}).map{|e| e["stock_name"]}
    @stock_abb_array.each_slice(100) {|su_arr|
      sub_url  = su_arr.join("+")

      # http://wern-ancheta.com/blog/2015/04/05/getting-started-with-the-yahoo-finance-api/
      # s: Symbol, a: Ask, b: Bid, b2: Ask (Realtime), b3: Bid (Realtime), k: 52 Week High, j: 52 week Low, 
      # j6: Percent Change From 52 week Low, k5: Percent Change From 52 week High, v: Volume, j1: Market Capitalization
      # full_url = "http://finance.yahoo.com/d/quotes.csv?s=#{sub_url}&f=sabb2b3jkj6k5vj1"

      # c1 – change
      # c – change & percentage change
      # c6 – change (realtime)
      # k2 – change percent
      # p2 – change in percent
      # d1 – last trade date
      # d2 – trade date
      # t1 – last trade time
      # c8 – after hours change

      full_url = "http://download.finance.yahoo.com/d/quotes.csv?s=#{sub_url}&f=sc1cc6k2p2d1d2t1c8"
      get_stockinfo_from_yahoo(full_url)
    }
  end

  def get_stockinfo_from_yahoo(url)
    CSV.new(open(url)).each do |line|
      if line[1] != "N/A"
        stock_name = line[0].to_s
        changed_value = line[1].to_f
        percent_stri  = line[5].to_s
        iS_increased  = false
        iS_xiangu     = false
        if percent_stri =~ /\+/
          iS_increased = true
        end
        percent_num = percent_stri.gsub(/\+|\-|\%/, '').to_f
        trade_date = line[6] #%d\%m%m\xxxx
        last_trade_time = line[8] # h:mm pm
        if iS_increased and percent_num > 20      
          puts "#{@count}"
          puts "Name: #{stock_name},  increase?: #{iS_increased},   percent: #{percent_num}, last_time: #{trade_date}-#{last_trade_time}"
          puts ""
        end
        minutes_run = ( Time.now.to_i - Time.parse("#{Time.now.strftime('%Y-%m-%d')} 09:30:00").to_i) / 60
        collection = @client[:stocks]
        three_minute_rate = percent_num / minutes_run * 3

# ============== how to define a xian gu ======================
        if percent_num > 30 and iS_increased
          iS_xiangu = true
        elsif ( three_minute_rate ) > 9 and iS_increased
          iS_xiangu = true
        end
# ================================================================


        if collection.find( { stock_name:  stock_name } ).first.nil?
          result = collection.insert_one({ stock_name: stock_name, 
                                           stock_increased: iS_increased,
                                           percent_num: percent_num,
                                           three_minute_rate: three_minute_rate,
                                           xian_gu: iS_xiangu
          })
        else
          result = collection.update_one( { stock_name: stock_name },
                                          { '$set': { stock_increased: iS_increased,
                                                      percent_num: percent_num,
                                                      three_minute_rate: three_minute_rate,
                                                      xian_gu: iS_xiangu 
                                        } } )
        end
        @count += 1
      end
    end
  end

end

puts "===================== >> 30% ================"
RealTimeXianStock.new(0.2).loop_stock_array


# CrawlStockName.new.get_stockinfo_from_yahoo("http://finance.yahoo.com/d/quotes.csv?s=AAPL+GOOG+NFLX&f=sabb2b3jkj6k5vj1")
# look at the reference here http://www.jarloo.com/yahoo_finance/