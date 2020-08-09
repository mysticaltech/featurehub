package io.featurehub.client.interceptor;

import io.featurehub.client.FeatureRepository;
import io.featurehub.client.FeatureStateHolder;
import io.opentelemetry.correlationcontext.CorrelationContext;

public class OpenTelemetryContextInjector {
  // this method just walks through the features, extracts their current values within the context
  // and appends them.
  public static void inject(CorrelationContext.Builder builder, FeatureRepository repository) {
    for(FeatureStateHolder fsh : repository.features()) {
      builder.put(OpenTelemetryValueInterceptor.FEATUREHUB_FEATURE_CONTEXT_PREFIX + fsh.getKey().replace(":", "_"),
        fsh.toString(), null
      );
    }

  }
}
