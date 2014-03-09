if /(mswin|mingw)/ =~ RUBY_PLATFORM
  /(\d+\.\d+)/ =~ RUBY_VERSION
  ver = $1
  require "#{ver}/lz4ruby.so"
elsif RUBY_PLATFORM == 'java'
  require 'lz4-jruby'
else
  require 'lz4ruby'
end

class LZ4
  def self.compress(input, in_size = nil)
    return _compress(input, in_size, false)
  end

  def self.compressHC(input, in_size = nil)
    return _compress(input, in_size, true)
  end
  
  def self._compress(input, in_size, high_compression)
    in_size = input.length if in_size == nil
    header = encode_varbyte(in_size)

    if high_compression
      return LZ4Internal.compressHC(header, input, in_size)
    else
      return LZ4Internal.compress(header, input, in_size)
    end
  end

  def self.uncompress(input, in_size = nil)
    in_size = input.length if in_size == nil
    out_size, varbyte_len = decode_varbyte(input)

    if out_size < 0 || varbyte_len < 0
      raise "Compressed data is maybe corrupted"
    end
    
    return LZ4Internal::uncompress(input, in_size, varbyte_len, out_size)
  end

  def self.raw_compress(*args)
    LZ4Internal.raw_compress(*args)
  end

  def self.raw_compressHC(*args)
    LZ4Internal.raw_compressHC(*args)
  end

  def self.raw_uncompress(*args)
    LZ4Internal.raw_uncompress(*args)
  end

  def self.encode_varbyte(val)
    varbytes = []

    loop do
      byte = val & 0x7f
      val >>= 7

      if val == 0
        varbytes.push(byte)
        break
      else
        varbytes.push(byte | 0x80)
      end
    end

    return varbytes.pack("C*")
  end

  def self.decode_varbyte(text)
    len = [text.length, 5].min
    bytes = text[0, len].unpack("C*")

    varbyte_len = 0
    val = 0
    bytes.each do |b|
      val |= (b & 0x7f) << (7 * varbyte_len)
      varbyte_len += 1
      return val, varbyte_len if b & 0x80 == 0
    end

    return -1, -1
  end

  class Raw
    def self.compress(input, options = {})
      input_size = options[:input_size]
      if input_size == nil
        input_size = input.length

      else
        if input.length < input_size
          raise ArgumentError, "`:input_size` (#{input_size}) must be less than or equal `input.length` (#{input.length})"
        end
      end

      dest = options[:dest]

      max_output_size = options[:max_output_size]
      if max_output_size == nil
        if dest != nil
          max_output_size = dest.length
        else
          max_output_size = input_size + (input_size / 255) + 16 if dest == nil
        end

      else
        if dest != nil && dest.length < max_output_size
          raise ArgumentError, "`:dest` buffer size (#{dest.length}) must be greater than or equal `:max_output_size` (#{max_output_size})"
        end
      end

      result = LZ4Internal.compress_raw(input, input_size, dest, max_output_size)

      if result[1] == 0
        raise LZ4Error, "compression failed"
      end

      return result[0], result[1]
    end
  end
end

class LZ4Error < StandardError
end
