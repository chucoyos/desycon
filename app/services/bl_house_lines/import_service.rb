# frozen_string_literal: true

require "csv"
require "roo"

module BlHouseLines
  class ImportService
    class ImportError < StandardError; end

    Result = Struct.new(:created_count, :errors, keyword_init: true)

    ALLOWED_EXTENSIONS = %w[csv xlsx].freeze
    DEFAULT_ROW_LIMIT = 500
    DEFAULT_SIZE_LIMIT = 2.megabytes

    HEADER_MAP = {
      "blhouse" => :blhouse,
      "cantidad" => :cantidad,
      "embalaje" => :packaging,
      "contiene" => :contiene,
      "marcas" => :marcas,
      "peso" => :peso,
      "volumen" => :volumen,
      "clase_imo" => :clase_imo,
      "tipo_imo" => :tipo_imo
    }.freeze

    REQUIRED_HEADERS = %i[blhouse cantidad packaging contiene marcas peso volumen].freeze

    def initialize(container:, file:, current_user:, row_limit: DEFAULT_ROW_LIMIT, size_limit: DEFAULT_SIZE_LIMIT)
      @container = container
      @file = file
      @current_user = current_user
      @row_limit = row_limit
      @size_limit = size_limit
    end

    def call
      validate_file!

      lines_to_import = []
      errors = []

      each_row_with_index do |row_attrs, index|
        break if index >= @row_limit

        line = build_line(row_attrs)

        if line.valid?
          lines_to_import << line
        else
          errors << "Fila #{index + 2}: #{line.errors.full_messages.to_sentence}"
        end
      rescue ImportError => e
        errors << "Fila #{index + 2}: #{e.message}"
      end

      return Result.new(created_count: 0, errors: errors) if errors.any?

      created_count = 0
      BlHouseLine.transaction do
        lines_to_import.each do |line|
          line.save!
          created_count += 1
        end
      end

      Result.new(created_count: created_count, errors: [])
    end

    private

    def validate_file!
      raise ImportError, "Selecciona un archivo." if @file.blank?
      raise ImportError, "El archivo excede el límite de #{@size_limit / 1.megabyte} MB." if @file.size > @size_limit

      ext = file_extension
      raise ImportError, "Formato no soportado. Usa XLSX o CSV." unless ALLOWED_EXTENSIONS.include?(ext)
    end

    def each_row_with_index(&block)
      ext = file_extension
      ext == "csv" ? each_csv_row(&block) : each_xlsx_row(&block)
    end

    def each_csv_row
      headers_checked = false

      CSV.foreach(@file.path, headers: true).with_index do |row, index|
        normalized_headers = normalize_headers(row.headers)
        ensure_required_headers!(normalized_headers) unless headers_checked
        headers_checked = true

        attrs = normalize_row(row.to_h)
        next if attrs.values.all?(&:blank?)

        yield attrs, index
      end
    end

    def each_xlsx_row
      xlsx = Roo::Spreadsheet.open(@file.path, extension: :xlsx)
      headers = normalize_headers(xlsx.row(1))
      ensure_required_headers!(headers)

      (2..xlsx.last_row).each_with_index do |row_number, index|
        row_values = xlsx.row(row_number)
        attrs = normalize_row(headers.zip(row_values).to_h)
        next if attrs.values.all?(&:blank?)

        yield attrs, index
      end
    end

    def normalize_headers(header_row)
      header_row.map { |h| h.to_s.strip.downcase }
    end

    def ensure_required_headers!(headers)
      available = headers.map { |h| HEADER_MAP[h] }.compact
      missing = REQUIRED_HEADERS - available
      return if missing.empty?

      raise ImportError, "Faltan columnas requeridas: #{missing.join(', ')}"
    end

    def normalize_row(raw_hash)
      normalized = {}

      raw_hash.each do |key, value|
        next unless key
        symbol = HEADER_MAP[key.to_s.strip.downcase]
        next unless symbol
        normalized[symbol] = value.is_a?(String) ? value.strip : value
      end

      normalized
    end

    def build_line(attrs)
      packaging = find_packaging(attrs[:packaging])
      raise ImportError, "Empaque no encontrado: #{attrs[:packaging]}" unless packaging

      BlHouseLine.new(
        blhouse: attrs[:blhouse],
        cantidad: safe_int(attrs[:cantidad]),
        contiene: attrs[:contiene],
        marcas: attrs[:marcas],
        peso: safe_decimal(attrs[:peso]),
        volumen: safe_decimal(attrs[:volumen]),
        clase_imo: attrs[:clase_imo],
        tipo_imo: attrs[:tipo_imo],
        packaging: packaging,
        container: @container,
        status: "activo"
      )
    end

    def find_packaging(value)
      return nil if value.blank?

      Packaging.where("LOWER(nombre) = ?", value.to_s.downcase).first
    end

    def safe_int(value)
      return nil if value.blank?
      value.to_i
    end

    def safe_decimal(value)
      return nil if value.blank?
      BigDecimal(value.to_s)
    rescue ArgumentError
      nil
    end

    def file_extension
      File.extname(@file.original_filename.to_s).delete_prefix(".").downcase
    end
  end
end
