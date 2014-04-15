module Solve
  class Graph
    def initialize
      @artifacts = {}
      @artifacts_by_name = Hash.new { |hash, key| hash[key] = [] }
    end

    # Check if an artifact with a matching name and version is a member of this instance
    # of graph
    #
    # @param [String] name
    # @param [Semverse::Version, #to_s] version
    #
    # @return [Boolean]
    def artifact?(name, version)
      !find(name, version).nil?
    end
    alias_method :has_artifact?, :artifact?

    def find(name, version)
      @artifacts["#{name}-#{version}"]
    end

    # Add an artifact to the graph
    #
    # @param [String] name
    # @Param [String] version
    def artifact(name, version)
      unless artifact?(name, version)
        artifact = Artifact.new(self, name, version)
        @artifacts["#{name}-#{version}"] = artifact
        @artifacts_by_name[name] << artifact
      end

      @artifacts["#{name}-#{version}"]
    end

    # Return the collection of artifacts
    #
    # @return [Array<Solve::Artifact>]
    def artifacts
      @artifacts.values
    end

    # Return all the artifacts from the collection of artifacts
    # with the given name.
    #
    # @param [String] name
    #
    # @return [Array<Solve::Artifact>]
    def versions(name, constraint = Semverse::DEFAULT_CONSTRAINT)
      constraint = Semverse::Constraint.coerce(constraint)

      if constraint == Semverse::DEFAULT_CONSTRAINT
        @artifacts_by_name[name]
      else
        @artifacts_by_name[name].select do |artifact|
          constraint.satisfies?(artifact.version)
        end
      end
    end

    # @param [Object] other
    #
    # @return [Boolean]
    def ==(other)
      return false unless other.is_a?(Graph)
      return false unless artifacts.size == other.artifacts.size

      self_artifacts = self.artifacts
      other_artifacts = other.artifacts

      self_dependencies = self_artifacts.inject([]) do |list, artifact|
        list << artifact.dependencies
      end.flatten

      other_dependencies = other_artifacts.inject([]) do |list, artifact|
        list << artifact.dependencies
      end.flatten

      self_dependencies.size == other_dependencies.size &&
      self_artifacts.all? { |artifact| other_artifacts.include?(artifact) } &&
      self_dependencies.all? { |dependency| other_dependencies.include?(dependency) }
    end
    alias_method :eql?, :==

    def prune(demands)
      require 'set'
      require 'pp'
      pruned_artifacts = Set.new

      demands.each do |name, constraint|
        collect_with_deps(name, constraint, pruned_artifacts)
      end

      pruned_graph = self.class.new
      pruned_artifacts.each do |a|
        copy_artifact = pruned_graph.artifact(a.name, a.version)
        a.dependencies.each do |dep|
          copy_artifact.depends(dep.name, dep.constraint)
        end
      end

      pruned_graph

    end

    def collect_with_deps(name, constraint, artifact_set)
      matching_artifacts = versions(name, constraint)
      if matching_artifacts.empty?
        puts "suspicious dependency constraint: #{name} #{constraint}"
      end
      matching_artifacts.each do |artifact|
        next if artifact_set.include?(artifact)
        artifact_set << artifact
        artifact.dependencies.each do |dependency|
          collect_with_deps(dependency.name, dependency.constraint, artifact_set)
        end
      end
    end

  end

end
