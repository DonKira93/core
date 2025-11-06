# frozen_string_literal: true

module IssueTransfer
  class Comparator
    def initialize(local_payload:, remote_payload:)
      @local = ensure_hash(deep_stringify(local_payload))
      @remote = ensure_hash(deep_stringify(remote_payload))
    end

    def diff
      compare_hash(local, remote)
    end

    private

    attr_reader :local, :remote

    def ensure_hash(value)
      value.is_a?(Hash) ? value : {}
    end

    def compare_hash(lhs, rhs, path = [])
      differences = []
      keys = (lhs.keys + rhs.keys).uniq

      keys.each do |key|
        new_path = path + [key]
        left_value = lhs[key]
        right_value = rhs[key]

        if left_value.is_a?(Hash) && right_value.is_a?(Hash)
          differences.concat(compare_hash(left_value, right_value, new_path))
        elsif left_value.is_a?(Array) && right_value.is_a?(Array)
          differences.concat(compare_array(left_value, right_value, new_path))
        elsif left_value != right_value
          differences << build_diff(new_path, left_value, right_value)
        end
      end

      differences
    end

    def compare_array(lhs, rhs, path)
      max = [lhs.length, rhs.length].max
      differences = []
      max.times do |index|
        left = lhs[index]
        right = rhs[index]
        new_path = path + [index]

        if left.is_a?(Hash) && right.is_a?(Hash)
          differences.concat(compare_hash(left, right, new_path))
        elsif left != right
          differences << build_diff(new_path, left, right)
        end
      end

      differences
    end

    def build_diff(path, local_value, remote_value)
      {
        path: path,
        local: local_value,
        remote: remote_value
      }
    end

    def deep_stringify(value)
      case value
      when Hash
        value.each_with_object({}) do |(k, v), memo|
          memo[k.to_s] = deep_stringify(v)
        end
      when Array
        value.map { |element| deep_stringify(element) }
      else
        value
      end
    end
  end
end
