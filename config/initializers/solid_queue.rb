require "fileutils"

# Ensure Solid Queue writes to a dedicated log file for easier troubleshooting.
log_path = Rails.root.join("log/solid_queue.log")
FileUtils.mkdir_p(log_path.dirname)

logger = ActiveSupport::Logger.new(log_path)
logger.level = Rails.logger.level
SolidQueue.logger = ActiveSupport::TaggedLogging.new(logger)

SolidQueue.logger.info("Solid Queue logger initialized")
SolidQueue.logger = ActiveSupport::Logger.new(Rails.root.join("log/solid_queue.log"))