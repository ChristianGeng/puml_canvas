class SubSample {
  const SubSample({required this.name, required this.source});
  final String name;
  final String source;
}

class SampleDiagram {
  const SampleDiagram({
    required this.name,
    required this.source,
    this.subSamples,
  });
  final String name;
  final String source;
  final List<SubSample>? subSamples;
}
