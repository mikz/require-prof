module RequireProf
  @@print_live = (print_live = ENV['RUBY_REQUIRE_PRINT_LIVE']) && (print_live != 'false')
  @@profile_memory = (memory = ENV['RUBY_REQUIRE_PROFILE_MEMORY'] and memory != 'false')

  @@orig_require = method(:require)
  @@orig_load = method(:load)
  @@global_start = Time.now
  @@global_memory = OS.rss_bytes
  @@level = 0
  @@lower_level_progress = 0
  @@lower_level_memory = 0
  @@timing_info = []
  @@memory_info = []

  def self.backend_requiring(orig_method, name, args)
    initial_lower_level_progress = @@lower_level_progress
    if @@profile_memory
      initial_lower_level_memory = @@lower_level_memory
    end

    spacing = ' ' * @@level
    start_at = Time.now

    if @@profile_memory
      start_memory = OS.rss_bytes
    end

    if @@print_live
      cumulative_duration = start_at - @@global_start
      $stderr.puts "#{spacing}[#{cumulative_duration}s] BEGIN #{name} #{args.inspect}..."

      if @@profile_memory
        cumulative_memory = start_memory - @@global_memory
        $stderr.puts "#{spacing}[#{cumulative_memory}s] BEGIN #{name} #{args.inspect}..."
      end
    end

    @@level += 1
    orig_method.call(*args)
    @@level -= 1

    end_at = Time.now

    if @@profile_memory
      end_memory = OS.rss_bytes
    end

    cumulative_duration = end_at - @@global_start
    total_duration = end_at - start_at
    my_duration = total_duration - (@@lower_level_progress - initial_lower_level_progress)

    if @@profile_memory
      cumulative_memory = end_memory - @@global_memory
      total_memory = end_memory - start_memory
      my_memory = total_memory - (@@lower_level_memory - initial_lower_level_memory)
    end

    if @@print_live
      print_timing_entry(my_duration, total_duration, cumulative_duration, spacing, "END #{name}", args)
      if @@profile_memory
        print_memory_entry(my_memory, total_memory, cumulative_memory, spacing, "END #{name}", args)
      end
    end

    @@timing_info << [my_duration, total_duration, cumulative_duration, spacing, name, args]
    @@lower_level_progress += my_duration

    if @@profile_memory
      @@memory_info << [my_memory, total_memory, cumulative_memory, spacing, name, args]
      @@lower_level_memory += my_memory
    end
  end

  def self.require(*args)
    backend_requiring(@@orig_require, 'requiring', args)
  end

  def self.load(*args)
    backend_requiring(@@orig_load, 'loading', args)
  end

  def self.print_timing_infos_for_optimization
    @@timing_info.sort_by { |timing| timing.first }.each do |my_duration, _, _, _, name, args|
      $stderr.puts "#{my_duration} s -- #{name} #{args.inspect}"
    end
    nil
  end

  def self.print_timing_infos
    @@timing_info.each { |entry| print_timing_entry(*entry) }
    nil
  end

  def self.print_memory_infos_for_optimization
    @@memory_info.sort_by(&:first).each do |my_memory, _, _, _, name, args|
      $stderr.puts "#{my_memory} b -- #{name} #{args.inspect}"
    end
    nil
  end

  def self.print_memory_infos
    @@memory_info.each { |entry| print_memory_entry(*entry) }
    nil
  end

  private

  def self.print_timing_entry(my_duration, total_duration, cumulative_duration, spacing, name, args)
    $stderr.puts "#{spacing}[#{cumulative_duration}s] #{name} #{args.inspect}. Took a cumulative #{total_duration}s (#{my_duration}s outside of sub-requires)."
  end

  def self.print_memory_entry(my_memory, total_memory, cumulative_memory, spacing, name, args)
    $stderr.puts "#{spacing}[#{cumulative_memory}b] #{name} #{args.inspect}. Took a cumulative #{total_memory}b (#{my_memory}b outside of sub-requires)."
  end
end

def require(*args)
  RequireProf.require(*args)
end

def load(*args)
  RequireProf.load(*args)
end
