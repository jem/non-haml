module Color
  COLORS = {clear: 0, red: 31, green: 32, yellow: 33, blue: 34, gray: 30, grey: 30}
  def self.method_missing(color_name, *args)
    if args.first.is_a? String
      color(color_name) + args.first + color(:clear) 
    else
      color(color_name) + args.first.inspect + color(:clear) 
    end
  end

  def self.color(color)
    "\e[#{COLORS[color.to_sym]}m"
  end
end
