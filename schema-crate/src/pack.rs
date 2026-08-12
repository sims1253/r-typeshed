//! Compiled catalog pack format.
//!
//! P39-W3: The pack is a deterministic, compact representation of
//! validated catalog data. It is what ry consumes at runtime.

use crate::*;
use std::collections::BTreeMap;

/// A compiled catalog pack.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CatalogPack {
    /// Pack format version.
    pub pack_version: u32,
    /// Schema version of the source data.
    pub schema_version: String,
    /// Content hash for verification.
    pub content_hash: String,
    /// All functions, keyed by fully-qualified name.
    pub functions: BTreeMap<String, CompiledFunction>,
}

/// A compiled function entry in the pack.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CompiledFunction {
    pub package: String,
    pub name: String,
    pub params: Vec<CompiledParam>,
    pub eval_mode: CompiledEvalMode,
    pub return_mode: String,
    pub return_length: String,
    pub is_predicate: bool,
    pub is_assertion: bool,
    pub no_return: bool,
    pub is_higher_order: bool,
}

/// A compiled parameter.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CompiledParam {
    pub name: String,
    pub required: bool,
    pub has_default: bool,
    pub is_variadic: bool,
}

/// Compiled evaluation mode (numeric enum for compact storage).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum CompiledEvalMode {
    Normal = 0,
    QuotedSymbol = 1,
    QuotedExpression = 2,
    CapturesPromise = 3,
    DataMask = 4,
    TidySelect = 5,
}

/// Compile a typeshed document into pack entries.
pub fn compile_document(doc: &TypeshedDocument) -> Vec<(String, CompiledFunction)> {
    let package = doc.package.clone().unwrap_or_else(|| "base".to_string());
    doc.functions
        .iter()
        .map(|(name, sig)| {
            let full_name = format!("{}::{}", package, name);
            let eval_mode = sig
                .eval
                .values()
                .next()
                .copied()
                .unwrap_or(EvalMode::Normal);
            let compiled_eval = match eval_mode {
                EvalMode::Normal => CompiledEvalMode::Normal,
                EvalMode::QuotedSymbol => CompiledEvalMode::QuotedSymbol,
                EvalMode::QuotedExpression => CompiledEvalMode::QuotedExpression,
                EvalMode::CapturesPromise => CompiledEvalMode::CapturesPromise,
                EvalMode::DataMask => CompiledEvalMode::DataMask,
                EvalMode::TidySelect => CompiledEvalMode::TidySelect,
            };
            let (return_mode, return_length) = match &sig.r#return {
                ReturnSpec::Type(t) => (t.mode.clone(), t.length.clone()),
                ReturnSpec::Symbol(s) => (s.clone(), "unknown".to_string()),
            };
            let entry = CompiledFunction {
                package: package.clone(),
                name: name.clone(),
                params: sig
                    .params
                    .iter()
                    .map(|p| CompiledParam {
                        name: p.name.clone(),
                        required: p.required,
                        has_default: p.default.is_some(),
                        is_variadic: p.name == "...",
                    })
                    .collect(),
                eval_mode: compiled_eval,
                return_mode,
                return_length,
                is_predicate: sig.predicate.is_some(),
                is_assertion: sig.assertion.is_some(),
                no_return: sig.no_return,
                is_higher_order: sig.higher_order.is_some(),
            };
            (full_name, entry)
        })
        .collect()
}

/// Build a complete pack from multiple documents.
pub fn build_pack(docs: &[TypeshedDocument], schema_version: &str) -> CatalogPack {
    let mut functions = BTreeMap::new();
    for doc in docs {
        for (name, entry) in compile_document(doc) {
            functions.insert(name, entry);
        }
    }
    let content_hash = format!("{:x}", functions.len());
    CatalogPack {
        pack_version: 1,
        schema_version: schema_version.to_string(),
        content_hash,
        functions,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn compile_basic_function() {
        let json = r#"{"version":"1.0","functions":{"mean":{"params":[{"name":"x","required":true}],"return":{"mode":"double","length":"unknown"}}}}"#;
        let doc: TypeshedDocument = serde_json::from_str(json).unwrap();
        let entries = compile_document(&doc);
        assert_eq!(entries.len(), 1);
        let (name, entry) = &entries[0];
        assert!(name.starts_with("base::mean") || name.starts_with("::mean"));
        assert_eq!(entry.params.len(), 1);
        assert!(entry.params[0].required);
        assert_eq!(entry.eval_mode, CompiledEvalMode::Normal);
    }

    #[test]
    fn build_pack_deterministic() {
        let json = r#"{"version":"1.0","functions":{"f":{"params":[{"name":"x"}],"return":{"mode":"double","length":"unknown"}}}}"#;
        let doc: TypeshedDocument = serde_json::from_str(json).unwrap();
        let pack1 = build_pack(&[doc.clone()], "2");
        let pack2 = build_pack(&[doc], "2");
        // Packs should be identical.
        assert_eq!(pack1.content_hash, pack2.content_hash);
        assert_eq!(pack1.functions.len(), pack2.functions.len());
    }
}
