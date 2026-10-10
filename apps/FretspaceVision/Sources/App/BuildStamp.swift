/// Human-visible build marker, bumped on every headset deploy so there is
/// never doubt about which build is being reviewed. Update the value in
/// the same commit as the change it ships.
enum BuildStamp {
    static let value = "v13 · passing dims, coherent heads, family glow"
}
