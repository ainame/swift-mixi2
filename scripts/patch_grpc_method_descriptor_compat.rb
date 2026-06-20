#!/usr/bin/env ruby
# Removes `type:` arguments from generated GRPCCore.MethodDescriptor calls.
# The currently pinned GRPCCore version does not yet accept that parameter.

generated_dir = File.expand_path("../Sources/Mixi2GRPC/Generated", __dir__)

Dir.glob(File.join(generated_dir, "*.grpc.swift")).each do |path|
  contents = File.read(path)
  patched = contents.gsub(/,\n(\s*)type: \.[A-Za-z]+/, "")
  next if patched == contents

  File.write(path, patched)
end
