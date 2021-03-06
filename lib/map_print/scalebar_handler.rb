require_relative 'png_handlers/texts'
require_relative 'validations/size'

module MapPrint
  class ScalebarHandler
    include PngHandlers::Texts
    include Validations::Size

    ZOOM_METERS_PER_PIXEL = {
      0 => 156543.03,
      1 => 78271.52,
      2 => 39135.76,
      3 => 19567.88,
      4 => 9783.94,
      5 => 4891.97,
      6 => 2445.98,
      7 => 1222.99,
      8 => 611.50,
      9 => 305.75,
      10 => 152.87,
      11 => 76.437,
      12 => 38.219,
      13 => 19.109,
      14 => 9.5546,
      15 => 4.7773,
      16 => 2.3887,
      17 => 1.1943,
      18 => 0.5972
    }
    def initialize(scalebar, zoom)
      @scalebar = scalebar
      @zoom = zoom
      if @scalebar[:padding]
        @padding_left = @scalebar[:padding][:left] || 0
        @padding_right = @scalebar[:padding][:right] || 0
        @padding_top = @scalebar[:padding][:top] || 0
        @padding_bottom = @scalebar[:padding][:bottom] || 0
      else
        @padding_left = 0
        @padding_right = 0
        @padding_top = 0
        @padding_bottom = 0
      end
      validate_data!
    end

    def process
      size = @scalebar[:size]
      tempfile = Tempfile.new ['scalebar', '.png']
      `convert -alpha on -channel a -evaluate set #{(@scalebar[:background_opacity] || 1) *100}% -density 300 -size #{size[:width]}x#{size[:height]} xc:#{@scalebar[:background_color] || 'transparent'} #{tempfile.path}`
      image = MiniMagick::Image.new tempfile.path

      pixels_for_distance = get_distance_in_units
      quarter = (size[:width] - @padding_left - @padding_right) / 4

      y_position = size[:height] - (@scalebar[:bar_height] || 10) - @padding_bottom
      orig_y = size[:height] - @padding_bottom
      image.combine_options do |c|
        c.density 300
        c.stroke 'black'
        (0..3).each do |i|
          c.fill (i % 2 == 0 ? 'white' : 'black')
          c.draw "rectangle #{@padding_left + i*quarter},#{orig_y} #{@padding_left + (i+1)*quarter},#{y_position}"
        end
      end

      text_options = { pointsize: 4, gravity: 'NorthWest' }.merge(@scalebar[:text_style] || {})
      draw_text(image, "0", "#{@padding_left},#{@padding_top}", text_options)
      draw_text(image, (pixels_for_distance/4).round(-2).to_s, "#{-quarter + @padding_left - @padding_right},#{@padding_top}", text_options.merge(gravity: 'North'))
      draw_text(image, (pixels_for_distance/2).round(-2).to_s, "#{@padding_left - @padding_right},#{@padding_top}", text_options.merge(gravity: 'North'))
      draw_text(image, (pixels_for_distance*0.75).round(-2).to_s + distance_units_to_s, "#{@padding_right},#{@padding_top}", text_options.merge(gravity: 'NorthEast'))

      image
    end

    private
    def validate_data!
      raise NoScalebarData.new('No scalebar data present') if @scalebar.nil? || @scalebar.empty?
      raise InvalidScalebarZoom.new('Zoom must be between 0..18') unless (0..18).include?(@zoom)
      validate_size!(@scalebar[:size], InvalidScalebarSize)
    end

    def get_distance_in_units
      padding = @padding_left + @padding_right
      meters = (@scalebar[:size][:width] - padding) * ZOOM_METERS_PER_PIXEL[@zoom]
      case @scalebar[:units]
      when 'km'
        meters / 1000
      when 'miles'
        meters * 0.0006213712
      when 'feet'
        meters * 3.28084
      else # asssume meters
        meters
      end
    end

    def distance_units_to_s
      case @scalebar[:units]
      when 'km'
        'km'
      when 'miles'
        'mi'
      when 'feet'
        'ft'
      else
        'm'
      end
    end
  end
end
