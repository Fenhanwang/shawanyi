class Stock
	include Mongoid::Document
	field :stock_name, type: String
  	field :stock_increased, type: Boolean
  	field :xian_gu, type: Boolean
  	field :percent_num, type: Float
  	field :three_minute_rate, type: Float
  	field :pre_market, type: Float	
end