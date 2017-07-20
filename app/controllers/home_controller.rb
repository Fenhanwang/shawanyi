class HomeController < ApplicationController
	def index
		@xian_gus = Stock.where(xian_gu: true)
	end
end
