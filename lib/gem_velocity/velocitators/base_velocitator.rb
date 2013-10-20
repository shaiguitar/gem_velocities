begin
  require 'active_support/all'
rescue
  'you need activesupport. please install'
end

class BaseVelocitator

  include ::Helpers

  attr_accessor :gem_name, :versions

  def graph(root_arg = nil, range = nil, min = nil, max = nil)
    set_overwritable_attrs(root_arg,range,min,max)
    gruff_builder.write
  end

  # modifiers on the end result image being rendered. Essentially these are the boundries
  # of the graph
  attr_reader :date_range, :max_value, :min_value, :root
  def date_range=(args); @passed_date_range = args && args.map{|t| time_format_str(t) } ;end
  def max_value=(max); @passed_max_value = max ;end
  def min_value=(min); @passed_min_value = min ;end
  def root=(path); @root = path ;end

  def effective_date_range
    @passed_date_range || default_date_range
  end

  def effective_max_value
    @passed_max_value || default_max_value
  end

  def effective_min_value
    @passed_min_value || default_min_value
  end

  def totals
    versions.map do |v|
      gem_data.total_for_version(v)
    end
  end

  def num_downloads
    sum = totals.map {|t| t[:version_downloads]}.sum
    ActiveSupport::NumberHelper.number_to_delimited(sum)
  end

  private

  def initialize(gem_name, versions)
    @gem_name = gem_name || raise(ArgumentError, 'need a name')
    @versions = versions || raise(ArgumentError, 'required versions')
    validate_correct_gem
    validate_correct_versions
  end

  def validate_correct_versions
    versions.each do |v|
      gem_data.versions.include?(v) || raise(NoSuchVersion,"version not found for #{versions}.")
    end
  end

  def validate_correct_gem
    # this will bomb out if bad version is passed.
    gem_data.versions_metadata
  end

  def set_overwritable_attrs(root_arg,range,min,max)
    self.date_range = range
    self.root = root_arg
    self.max_value = max
    self.min_value = min
  end

  def default_end
    default_end = time_format_str(Time.now)
  end

  def default_date_range
    [ default_start, default_end ]
  end

  def default_min_value
    0
  end

  def default_line_datas
    versions.map do |v|
      effective_days_in_range.map do |d|
        downloads_per_day(v)[d] || 0
      end
    end
  end

  def base_earliest_time_for(verzionz)
    earliest_start = verzionz.map{|v| Date.parse(time_built(v)) }.min
    default_start = time_format_str(earliest_start)
  end

  def base_max_for(verzionz)
    totals = []
    verzionz.each {|v|
      totals << downloads_per_day(v).map {|day,total| total}
    }
    totals.flatten.compact.max
  end

  def downloads_per_day(version)
    # returns # "2013-10-10" => 45
    accumulated_downloads_per_day(version)
  end

  def accumulated_downloads_per_day(version)
    # downloads_metadata comes back ordered by date
    ret = Hash.new(0)
    gem_data.downloads_metadata(version, default_start, default_end).each_cons(2) do |p,n|
      #day,total pairs
      curr_total = n.last
      day = n.first
      previous_day = p.first
      ret[day] = curr_total + ret[previous_day]
    end
    ret
  end

  # a little sugar
  def effective_start_time; effective_date_range.first ;end
  def effective_end_time; effective_date_range.last ;end

  # helper method to convert [start,end] into a 
  # start..end range of days like "2013-10-10"
  def effective_days_in_range
    all_days = []
    s = Date.parse(effective_start_time)
    e = Date.parse(effective_end_time)
    i = s
    while (i <= e )
      all_days << i
      i += 1.day
    end
    all_days.map{|d| time_format_str_small(d)}
  end

  def gem_data
    # need this memoized so the gem_data memoization works for the same instance
    @gem_data ||= GemData.new(@gem_name)
  end

  def gruff_builder
    GruffBuilder.new(@root || Dir.pwd,nil,versions,gem_name,graph_options)
  end

  # it's just shorter syntax
  def time_built(version)
    gem_data.versions_built_at[version]
  end
 
end