package io.featurehub.client.interceptor;

import io.featurehub.client.FeatureValueInterceptor;
import io.opentelemetry.OpenTelemetry;
import io.opentelemetry.correlationcontext.Entry;

/**
 * OpenTelemetry is different in that it uses the gRPC Context object to store
 * context data.
 */
public class OpenTelemetryValueInterceptor implements FeatureValueInterceptor {
  public static final String FEATUREHUB_FEATURE_CONTEXT_PREFIX = "fhub.";

  @Override
  public ValueMatch getValue(String key) {
    String finalKey = FEATUREHUB_FEATURE_CONTEXT_PREFIX + key.replace(":",
      "_");
    for(Entry entry : OpenTelemetry.getCorrelationContextManager().getCurrentContext().getEntries()) {
      if (entry.getKey().equals(finalKey)) {
        return new ValueMatch(true, entry.getValue());
      }
    }

    return null;
  }
}
