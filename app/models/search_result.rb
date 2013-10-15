class SearchResult
  
  include Enumerable
  extend Forwardable

  attr_reader :klass, :tire_response

  def initialize(model_name, response)
    @klass = model_name.classify.constantize
    @tire_response = response
  end
    
  # Find results with where rather than find in order to avoid ActiveRecord::RecordNotFound
  def items
    @items ||= items_from_response
  end

  def facets
    @facets ||= facets_from_response(tire_response.facets)
  end

  def each(&block)
    items.each(&block)
  end

  def empty?
    items.empty?
  end

  def size
    items.size
  end
  alias :length :size

  def [](index)
    items[index]
  end

  def to_ary
    self
  end

  def_delegators :@tire_response, :total_pages, :total_entries, :per_page, :offset, :current_page

  private

  #############
  # ITEMS #####
  #############

  # We step through the items array in order to preserve the original response order
  def items_from_response
    ids = item_ids
    items = klass.where(:id => ids).group_by(&:id)
    ordered_items(ids, items)
  end

  def item_ids
    tire_response.results.map { |item| item['id'] }
  end

  def ordered_items(ids, items)
    ids.map{ |id| items[id.to_i] }.flatten.compact
  end

  #############
  # FACETS ####
  #############

  # Given a response facets hash
  # create a hash with the key being the category ('character', 'fandom')
  # and the value being an array of search result objects
  def facets_from_response(facets)
    return if facets.nil?
    {}.tap {|hash| facets.each{|term, results| hash[term] = facets_for_term(term, results['terms'])}}
  end

  # As with items, loop through the results list in order to maintain order
  def facets_for_term(term, results)
    facets = []
    klass = term.classify.constantize
    ids = results.map{ |result| result['term'] }
    facet_objects = klass.where(id: ids).group_by(&:id)
    results.each do |facet|
      id = facet['term'].to_i
      unless facet_objects[id].blank?
        facets << SearchFacet.new(id.to_s, facet_objects[id].first.label, facet['count'])
      end
    end
    facets
  end
  
end

class SearchFacet < Struct.new(:id, :name, :count)
end
