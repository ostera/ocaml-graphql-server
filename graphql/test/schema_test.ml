let test_query = Test_common.test_query Test_schema.schema ()

let suite = [
  ("query", `Quick, fun () ->
    let query = "{ users { id } }" in
    test_query query (`Assoc [
      "data", `Assoc [
        "users", `List [
          `Assoc [
            "id", `Int 1
          ];
          `Assoc [
             "id", `Int 2
          ]
        ]
      ]
    ])
  );
  ("mutation", `Quick, fun () ->
    let query = "mutation { add_user(name: \"Charlie\", role: \"user\") { name } }" in
    test_query query (`Assoc [
      "data", `Assoc [
        "add_user", `List [
          `Assoc [
            "name", `String "Alice"
          ];
          `Assoc [
            "name", `String "Bob"
          ];
          `Assoc [
            "name", `String "Charlie"
          ]
        ]
      ]
    ])
  );
  ("__typename", `Quick, fun () ->
    let query = "{ __typename }" in
    test_query query (`Assoc [
      "data", `Assoc [
        "__typename", `String "query"
      ]
    ])
  );
  ("select operation (no operations)", `Quick, fun () ->
    let query = "fragment x on y { z }" in
    test_query query (`Assoc [
      "errors", `List [
        `Assoc [
          "message", `String "No operation found"
        ]
      ]
    ])
  );
  ("select operation (one operation, no operation name)", `Quick, fun () ->
    let query = "a { a: __typename }" in
    test_query query (`Assoc [
      "data", `Assoc [
        "a", `String "query"
      ]
    ])
  );
  ("select operation (one operation, matching operation name)", `Quick, fun () ->
    let query = "a { a: __typename }" in
    test_query query ~operation_name:"a" (`Assoc [
      "data", `Assoc [
        "a", `String "query"
      ]
    ])
  );
  ("select operation (one operation, missing operation name)", `Quick, fun () ->
    let query = "a { a: __typename }" in
    test_query query ~operation_name:"b" (`Assoc [
      "errors", `List [
        `Assoc [
          "message", `String "Operation not found"
        ]
      ]
    ])
  );
  ("select operation (multiple operations, no operation name)", `Quick, fun () ->
    let query = "a { a: __typename } b { b: __typename }" in
    test_query query (`Assoc [
      "errors", `List [
        `Assoc [
          "message", `String "Operation name required"
        ]
      ]
    ])
  );
  ("select operation (multiple operations, matching operation name)", `Quick, fun () ->
    let query = "a { a: __typename } b { b: __typename }" in
    test_query query ~operation_name:"b" (`Assoc [
      "data", `Assoc [
        "b", `String "query"
      ]
    ])
  );
  ("select operation (multiple operations, missing operation name)", `Quick, fun () ->
    let query = "a { a: __typename } b { b: __typename }" in
    test_query query ~operation_name:"c" (`Assoc [
      "errors", `List [
        `Assoc [
          "message", `String "Operation not found"
        ]
      ]
    ])
  );
  ("fragments cannot form cycles", `Quick, fun () ->
    let query = "
      fragment F1 on Foo {
        ... on Bar {
          baz {
            ... F2
          }
        }
      }

      fragment F2 on Qux {
        ... F1
      }

      {
        ... F1
      }
    " in
    test_query query (`Assoc [
      "errors", `List [
        `Assoc [
          "message", `String "Fragment cycle detected: F1, F2"
        ]
      ]
    ])
  );
  ("introspection query should be accepted", `Quick, fun () ->
    let query = "
      query IntrospectionQuery {
        __schema {
          queryType { name }
          mutationType { name }
          subscriptionType { name }
          types {
            ...FullType
          }
          directives {
            name
            description
            locations
            args {
              ...InputValue
            }
          }
        }
      }

      fragment FullType on __Type {
        kind
        name
        description
        fields(includeDeprecated: true) {
          name
          description
          args {
            ...InputValue
          }
          type {
            ...TypeRef
          }
          isDeprecated
          deprecationReason
        }
        inputFields {
          ...InputValue
        }
        interfaces {
          ...TypeRef
        }
        enumValues(includeDeprecated: true) {
          name
          description
          isDeprecated
          deprecationReason
        }
        possibleTypes {
          ...TypeRef
        }
      }

      fragment InputValue on __InputValue {
        name
        description
        type { ...TypeRef }
        defaultValue
      }

      fragment TypeRef on __Type {
        kind
        name
        ofType {
          kind
          name
          ofType {
            kind
            name
            ofType {
              kind
              name
              ofType {
                kind
                name
                ofType {
                  kind
                  name
                  ofType {
                    kind
                    name
                    ofType {
                      kind
                      name
                    }
                  }
                }
              }
            }
          }
        }
      }
    " in
    match Graphql_parser.parse query with
    | Error err -> failwith err
    | Ok doc ->
        begin match Graphql.Schema.execute Test_schema.schema () doc with
        | Ok _ -> ()
        | Error err -> failwith (Yojson.Basic.pretty_to_string err)
        end
  );
]
