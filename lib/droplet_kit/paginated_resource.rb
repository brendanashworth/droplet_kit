module DropletKit
  class PaginatedResource
    include Enumerable

    PER_PAGE = 20

    attr_reader :action, :connection, :collection
    attr_accessor :total

    def initialize(action_connection, *args)
      @current_page = 0
      @total = nil
      @action = action_connection.action
      @connection = action_connection.connection
      @collection = []
      @args = args
      @options = args.last.kind_of?(Hash) ? args.last : {}
    end

    def per_page
      @options[:per_page] || PER_PAGE
    end

    def each(start = 0)
      # Start off with the first page if we have no idea of anything yet
      fetch_next_page if total.nil?

      return to_enum(:each, start) unless block_given?
      Array(@collection[start..-1]).each do |element|
        yield(element)
      end

      unless last?
        start = [@collection.size, start].max
        fetch_next_page
        each(start, &Proc.new)
      end

      self
    end

    def last?
      @current_page == (self.total.to_f / per_page.to_f).ceil
    end

    def ==(other)
      return false if self.total != other.length
      each_with_index.each.all? {|object, index| object == other[index] }
    end

    private

    def fetch_next_page
      @current_page += 1
      retrieve(@current_page)
    end

    def retrieve(page, per_page = self.per_page)
      invoker = ResourceKit::ActionInvoker.new(action, connection, *@args)
      invoker.options[:per_page] ||= per_page
      invoker.options[:page]       = page

      @collection += invoker.handle_response

      if total.nil?
        meta = MetaInformation.extract_single(invoker.response.body, :read)
        self.total = meta.total.to_i
      end
    end
  end
end