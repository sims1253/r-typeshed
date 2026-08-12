//! Authoring schema for r-typeshed.
//!
//! This crate defines the JSON authoring format for function semantics.
//! It is the independently versioned contract between r-typeshed
//! authors and ry's catalog adapter.
//!
//! The schema is neutral: it does not depend on ry's AST, checker,
//! or `RType`. Ry maps catalog values into its internal semantic model.

#![forbid(unsafe_code)]

use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

// == Top-level typeshed document ==

/// A complete typeshed document describing one R package.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TypeshedDocument {
    pub schema_version: Option<String>,
    pub package: Option<String>,
    pub version: String,
    pub functions: BTreeMap<String, FunctionSignature>,
    #[serde(default)]
    pub globals: Globals,
    #[serde(default)]
    pub datasets: BTreeMap<String, RTypeSpec>,
    #[serde(default)]
    pub s3_methods: BTreeMap<String, BTreeMap<String, RTypeSpec>>,
}

// == Function signature ==

/// Function signature in the authoring format.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FunctionSignature {
    pub params: Vec<ParameterDef>,
    pub r#return: ReturnSpec,
    #[serde(default)]
    pub aliases: Vec<String>,
    #[serde(default)]
    pub eval: BTreeMap<String, EvalMode>,
    #[serde(default)]
    pub no_return: bool,
    #[serde(default)]
    pub data_mask_source: Option<String>,
    #[serde(default)]
    pub predicate: Option<PredicateDef>,
    #[serde(default)]
    pub assertion: Option<AssertionDef>,
    #[serde(default)]
    pub return_length: Option<ReturnLengthDef>,
    #[serde(default)]
    pub higher_order: Option<HigherOrderDef>,
    #[serde(default)]
    pub injects: Vec<InjectDef>,
}

// == Parameter definition ==

/// A parameter in a function signature.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ParameterDef {
    pub name: String,
    #[serde(rename = "type", skip_serializing_if = "Option::is_none")]
    pub type_: Option<RTypeSpec>,
    #[serde(default)]
    pub required: bool,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub default: Option<bool>,
}

// == R type specification ==

/// An R type specification in the authoring format.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RTypeSpec {
    pub mode: String,
    pub length: String,
    #[serde(default)]
    pub na: bool,
    #[serde(default)]
    pub class: Vec<String>,
    #[serde(default)]
    pub columns: BTreeMap<String, RTypeSpec>,
}

// == Evaluation modes ==

/// How a parameter is evaluated.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum EvalMode {
    Normal,
    QuotedSymbol,
    QuotedExpression,
    CapturesPromise,
    DataMask,
    TidySelect,
}

// == Return specification ==

/// Return type specification.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(untagged)]
pub enum ReturnSpec {
    Type(RTypeSpec),
    Symbol(String),
}

// == Semantic effect definitions ==

/// Predicate narrowing specification.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PredicateDef {
    pub subject_param: String,
    pub target: RTypeSpec,
}

/// Assertion specification.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AssertionDef {
    pub subject_param: String,
    pub target: RTypeSpec,
}

/// Return length specification.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ReturnLengthDef {
    pub kind: String,
}

/// Higher-order function specification.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HigherOrderDef {
    pub callback_param: String,
    pub callback_position: usize,
    pub result: String,
}

/// Binding injection specification.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InjectDef {
    pub into: Vec<String>,
    #[serde(default)]
    pub names: Vec<String>,
}

// == Globals ==

/// Package-level global bindings.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct Globals {
    #[serde(default)]
    pub names: Vec<String>,
    #[serde(default)]
    pub s3_generics: Vec<String>,
}

// == Validation ==

/// Validate that a document conforms to basic schema constraints.
pub fn validate(doc: &TypeshedDocument) -> Result<(), Vec<String>> {
    let mut errors = Vec::new();

    if doc.version.is_empty() {
        errors.push("version must not be empty".to_string());
    }

    for (name, sig) in &doc.functions {
        if sig.params.is_empty() && name != "..." {
            // Zero-arg primitives are valid
        }
        for param in &sig.params {
            if param.name.is_empty() {
                errors.push(format!("function {} has unnamed parameter", name));
            }
        }
    }

    if errors.is_empty() {
        Ok(())
    } else {
        Err(errors)
    }
}

pub mod pack;
pub use pack::{
    build_pack, compile_document, CatalogPack, CompiledEvalMode, CompiledFunction, CompiledParam,
};

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_minimal_document() {
        let json = r#"{"version":"1.0","functions":{}}"#;
        let doc: TypeshedDocument = serde_json::from_str(json).unwrap();
        assert_eq!(doc.version, "1.0");
        assert!(doc.functions.is_empty());
    }

    #[test]
    fn parse_function_with_params() {
        let json = r#"{"version":"1.0","functions":{"f":{"params":[{"name":"x"}],"return":{"mode":"double","length":"unknown"}}}}"#;
        let doc: TypeshedDocument = serde_json::from_str(json).unwrap();
        let sig = doc.functions.get("f").unwrap();
        assert_eq!(sig.params.len(), 1);
        assert_eq!(sig.params[0].name, "x");
    }

    #[test]
    fn validate_rejects_empty_version() {
        let doc = TypeshedDocument {
            schema_version: None,
            package: None,
            version: "".to_string(),
            functions: BTreeMap::new(),
            globals: Globals::default(),
            datasets: BTreeMap::new(),
            s3_methods: BTreeMap::new(),
        };
        assert!(validate(&doc).is_err());
    }
}
