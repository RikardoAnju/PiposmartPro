use axum::{
    routing::{get, post},
    Json, Router,
};
use serde::{Deserialize, Serialize};
use std::net::SocketAddr;
use tower::ServiceBuilder;
use tower_http::cors::CorsLayer;
use tracing::info;

#[derive(Debug, Serialize, Deserialize)]
struct HealthResponse {
    status: String,
    service: String,
}

async fn health() -> Json<HealthResponse> {
    Json(HealthResponse {
        status: "ok".to_string(),
        service: "piposmart-report-service".to_string(),
    })
}

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt::init();

    let app = Router::new()
        .route("/health", get(health))
        .layer(ServiceBuilder::new().layer(CorsLayer::permissive()));

    let addr = SocketAddr::from(([0, 0, 0, 0], 3002));
    let listener = tokio::net::TcpListener::bind(&addr).await.unwrap();
    
    info!("Report Service listening on {}", addr);
    
    axum::serve(listener, app).await.unwrap();
}
