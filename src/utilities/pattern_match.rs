pub fn component_matches_pattern(component: &str, pattern: &str) -> bool {
    let component = component.to_lowercase();

    if pattern.starts_with('*') && pattern.ends_with('*') {
        let inner = &pattern[1..pattern.len() - 1];
        component.contains(inner)
    } else if pattern.starts_with('*') {
        let suffix = pattern.strip_prefix('*').unwrap_or(pattern);
        component.ends_with(suffix)
    } else if pattern.ends_with('*') {
        let prefix = pattern.strip_suffix('*').unwrap_or(pattern);
        component.starts_with(prefix)
    } else {
        component == pattern
    }
}
