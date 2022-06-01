# Represents a hierarchy of individuals as a flat list of {Item}s.
class IndividualHierarchy
  # @param base [ActiveRecord class, ActiveRecord_Relation, Individual] The individual or set of
  #   individuals the hierarchy should be based on.
  # @param predicate [String] The predicate the hierarchy is based on.
  def initialize base, predicate, expand_hierarchy = false
    @predicate = predicate
    @expand_hierarchy = expand_hierarchy

    if base.is_a?(Class) && base < ActiveRecord::Base
      # No base relation is given, just a class. In this case, use all records of this class.
      @klass = base
      @relation = @klass.all.order(:inline_label)
    elsif base.is_a?(Individual)
      # base is an individual. This means that the hierarchy should be created for its klass, but
      # with the individual as the only top-level individual.
      @single_top = base
      @klass = base.class
      @relation = @klass.all.order(:inline_label)
    elsif base.is_a?(ActiveRecord::Relation)
      # base is a Relation (like `Concept.where(id: [1, 2, 3])`) that limits the set of individuals
      # considered.
      @klass = base.klass
      @relation = base
    else
      raise "Invalid base"
    end
  end

  def items
    return @items if @items
    @items = top_level_indis.flat_map { |indi| inner_items(indi) }

    # We need to determine the descendants for each item. Deduce them from the ancestors of the
    # items.
    # TODO Could we use the children_cache for this and do it will while building the hierarchy?
    @items.each do |outer_item|
      @items.each do |inner_item|
        if inner_item.ancestors.include?(outer_item.indi)
          outer_item.descendants << inner_item.indi
        end
      end
    end

    @items
  end

  private

  # Can't do this in the main `items` method because we need to do two passes to collect
  # the descendants.
  def inner_items indi, level=0, ancestors=[]
    #puts "inner_items: indi=#{indi} level=#{level} ancestors=#{ancestors.map(&:to_s).join(", ")}"
    first = Item.new(indi, level, ancestors)
    children = children_cache[indi].sort_by(&:label)

    raise CircleError, "Circular! indi=#{indi} level=#{level}" unless (ancestors & children).empty?

    children_items = children.flat_map { |child| inner_items(child, level + 1, ancestors + [indi]) }
    [first] + children_items
  end

  # Build a hash that caches the children (insofar as they are in the set of individuals
  # considered) of each individual in the hierarchy.
  # Also build the list of top-level individuals.
  def build_cache
    @children_cache = Hash.new { |h, k| h[k] = [] } # Default-Wert ist [] (statt nil)
    @top_level_indis = []
    @relation.includes(inverse_predicate => :objekt).each do |indi|
      # Mapping instead of "..._value" to be able to use includes.
      parents = indi.send(inverse_predicate).map(&:value)

      parents.each do |parent|
        # Need this condition, because it might be false because of the above loop.
        unless @children_cache[parent].include?(indi)
          @children_cache[parent] << indi
        end
      end

      unless @expand_hierarchy
        # Need to make sure that all parents are in @relation. If not, consider the parents' parents
        # as the actual parents. This is needed for property hierarchies where not all individuals
        # in the chain are selected (which is something we can't enforce).
        loop do
          all_parents_in_relation = true
          parents.each_with_index do |parent, index|
            unless @relation.include?(parent)
              all_parents_in_relation = false
              parents[index] = parent.send("#{inverse_predicate}_value")
            end
          end
          if all_parents_in_relation
            break
          else
            parents.flatten!
          end
        end
        
        if parents.empty?
          @top_level_indis << indi
        end
        
        parents.each do |parent|
          # Need this condition, because it might be false because of the above loop.
          unless @children_cache[parent].include?(indi)
            @children_cache[parent] << indi
          end
        end
        
      else
        
        if parents.empty?
          @top_level_indis << indi
        end
        
        parents_with_flags = parents.collect{|parent| [parent, false]}
        loop do
          parents_with_flags.each_with_index do |parent_arr, index|
            parent = parent_arr[0]
            checked_for_parents = parent_arr[1]
            unless checked_for_parents
              parents_parents = parent.send("#{inverse_predicate}_value")
              parents_with_flags[index][1] = true
              parents_parents_with_flags = parents_parents.collect{|parent| [parent, false]}
              parents_with_flags += parents_parents_with_flags
              
              if parents_parents.empty?
                @top_level_indis << parent
              end
              #byebug if parent == Subject.find(45)
              parents_parents.each do |parents_parent|
                # Need this condition, because it might be false because of the above loop.
                unless @children_cache[parents_parent].include?(parent)
                  @children_cache[parents_parent] << parent
                end
              end
            end
          end
          if parents_with_flags.all?{|_,checked_for_parents| checked_for_parents} 
            break
          end
        end
        
        parents = parents_with_flags.collect{|parent,_| parent}
        
        @top_level_indis.uniq!
        @top_level_indis.sort_by!{|indi| indi.inline_label}
      end
    end
  end

  def children_cache
    build_cache unless @children_cache
    @children_cache
  end

  def top_level_indis
    return [@single_top] if @single_top
    build_cache unless @top_level_indis
    @top_level_indis
  end

  def inverse_predicate
    @inverse_predicate ||= @klass.inverse_of(@predicate)
  end

  class CircleError < StandardError; end

  # Represents a hierarchy item.
  class Item
    attr_reader :indi, :level, :ancestors, :descendants

    def initialize indi, level, ancestors, descendants=[]
      @indi = indi
      @level = level
      @ancestors = ancestors
      @descendants = descendants
    end
  end
end
