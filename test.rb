  require "json"
  require "securerandom"

  template_paragraphs = Array.new(8) do |idx|
    <<~PARA
      Paragraph #{idx + 1}: We revisit the prior diff, discuss range iterations, and highlight
      how to migrate MCP transcripts into a Rails persistence layer. The agenda touches on
      vector search, tool metadata exposure, and the nuances of running Ollama locally on
      constrained hardware. Each section elaborates on failure recovery, performance tuning,
      and schema evolution patterns that tend to surface once embeddings are introduced at scale.
    PARA
  end

  requests = Array.new(20) do |i|
    prompt_body = [
      "Conversation chunk ##{i + 1} — exploring adapter semantics",
      template_paragraphs.join("\n"),
      "Code sample:",
      "````ruby\n(0..(info[:number_clinics].to_i - 1)).each do |c|\n  # migrated to Integer#times\nend\n````"
    ].join("\n\n")

    response_summaries = Array.new(6) do |j|
      <<~NOTE
        Response summary #{j + 1}: The assistant reiterates the migration strategy, references
        structured output validation, and cites instrumentation hooks that must wrap the
        embedding call to track latency, throughput, and warm-start characteristics for the
        mahonzhan/all-MiniLM-L6-v2 model when running under sustained load.
      NOTE
    end

    {
      requestId: "request_#{format("%04d", i)}_#{SecureRandom.uuid.delete("-")[0, 8]}",
      message: {
        text: prompt_body,
        parts: [
          { kind: "text", text: prompt_body }
        ]
      },
      variableData: {
        variables: [
          {
            name: "prompt:copilot-instructions.md",
            value: "file:///Users/kira/dev/iq/.github/copilot-instructions.md"
          },
          {
            name: "settings:temperature",
            value: (0.4 + (i * 0.02)).round(2)
          }
        ]
      },
      response: [
        { kind: "mcpServersStarting", didStartServerIds: ["memory_embedder", "search_bridge"] },
        { kind: "text", value: response_summaries.join("\n") },
        {
          kind: "code",
          value: <<~RUBY
            RubyLLM.chat(model: "llama3.1:8b", provider: :ollama) do |chat|
              chat.with_instructions("Keep responses focused on embeddings and MCP tooling.")
              chat.ask("Summarize chunk #{i + 1} with additional telemetry guidance.")
            end
          RUBY
        }
      ]
    }
  end

  payload = {
    requesterUsername: "DonKira93",
    responderUsername: "GitHub Copilot",
    initialLocation: "panel",
    requests: requests
  }

  document = [
    "Requester: #{payload[:requesterUsername]}",
    "Responder: #{payload[:responderUsername]}",
    "Location: #{payload[:initialLocation]}",
    payload[:requests].map do |req|
      <<~TEXT
        Request #{req[:requestId]}:
        Prompt:\n#{req.dig(:message, :text)}

        Variables:
        #{req.dig(:variableData, :variables)&.map { |var| "#{var[:name]} -> #{var[:value]}" }&.join("\n") || "(none)"}

        Responses:
        #{req[:response].map { |chunk| "#{chunk[:kind]} -> #{chunk[:value] || chunk[:didStartServerIds]}" }.join("\n")}
      TEXT
    end
  ].flatten.join("\n\n---\n\n")

  puts "Requests: #{payload[:requests].size}"
  puts "Payload length: #{document.length} characters"

  started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  embedding = Llm::OllamaClient.embed_text(document)
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at

  vector = embedding.vectors
  vector = vector.first if vector.first.is_a?(Array)

  dimensions = vector.size
  preview = vector.take(5).map { |x| format("%0.4f", x) }.join(", ")

  puts format("Embedding took %.2f seconds", elapsed)
  puts "Received #{dimensions} dimensions (#{preview} ...)"
