apiVersion: v1
kind: Namespace
metadata:
  name: calorie-tracker
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: calorie-tracker-postgres-init
  namespace: calorie-tracker
data:
  init: |
    CREATE DATABASE hdb_catalog;
---
apiVersion: v1
kind: Secret
metadata:
  name: regcred
  namespace: calorie-tracker
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: "dockerconfigjson_placeholder"
---
apiVersion: v1
kind: Secret
metadata:
  name: calorie-tracker
  namespace: calorie-tracker
type: Opaque
data:
  POSTGRES_PASSWORD: "postgres_password_placeholder"
  HASURA_GRAPHQL_ADMIN_SECRET: "hasura_graphql_admin_secret_placeholder"
  HASURA_GRAPHQL_JWT_SECRET: "hasura_graphql_jwt_secret_placeholder"
  HASURA_GRAPHQL_DATABASE_URL: "pg_conn_string_placeholder"
  PG_DATABASE_URL: "pg_conn_string_placeholder"
  HASURA_GRAPHQL_METADATA_DATABASE_URL: "pg_conn_string_placeholder"
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: calorie-tracker-postgres
  namespace: calorie-tracker
spec:
  resources:
    requests:
      storage: 5Gi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteOnce
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: calorie-tracker-migrations
  namespace: calorie-tracker
spec:
  resources:
    requests:
      storage: 1Gi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteOnce
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: calorie-tracker-metadata
  namespace: calorie-tracker
spec:
  resources:
    requests:
      storage: 1Gi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteOnce
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: client-deployment
  namespace: calorie-tracker
  labels:
    app: calorie-tracker-client
spec:
  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
    type: RollingUpdate
  selector:
    matchLabels:
      app: calorie-tracker-client
  template:
    metadata:
      labels:
        app: calorie-tracker-client
    spec:
      restartPolicy: Always
      imagePullSecrets:
      - name: regcred
      containers:
      - image: client_container_img_placeholder
        imagePullPolicy: IfNotPresent
        name: client
        livenessProbe:
          httpGet:
            path: /index.html
            port: 3000
          initialDelaySeconds: 10
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /index.html
            port: 3000
          initialDelaySeconds: 10
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        env:
        - name: HASURA_GRAPHQL_JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: calorie-tracker
              key: HASURA_GRAPHQL_JWT_SECRET
        - name: NEXT_PUBLIC_VERSION
          value: ac376c7ad29ee2a6c53c285d75b4d9b20f8a87fb
        - name: HASURA_GRAPHQL_MIGRATIONS_SERVER_TIMEOUT
          value: "120"
        - name: NEXT_PUBLIC_HASURA_DOMAIN
          value: domain_name_placeholder
        - name: NEXT_PUBLIC_FIREBASE_CONFIG
          value: '{}'
        - name: NEXT_PUBLIC_LOGIN_WITH_APPLE
          value: 'no'
        - name: NEXT_PUBLIC_LOGIN_WITH_FACEBOOK
          value: 'no'
        - name: NEXT_PUBLIC_LOGIN_WITH_GITHUB
          value: 'no'
        - name: NEXT_PUBLIC_LOGIN_WITH_GOOGLE
          value: 'no'
        - name: NEXT_PUBLIC_REACT_SENTRY_DSN
          value: ''
        - name: NEXT_PUBLIC_USE_FIREBASE
          value: 'no'
        ports:
        - containerPort: 3000
          name: client
          protocol: TCP
---
apiVersion: v1
kind: Service
metadata:
  name: client-service
  namespace: calorie-tracker
spec:
  selector:
    app: calorie-tracker-client
  type: ClusterIP
  ports:
  - name: client-port
    port: 3000
    targetPort: 3000
    protocol: TCP
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hasura-deployment
  namespace: calorie-tracker
  labels:
    app: calorie-tracker-hasura
spec:
  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
    type: RollingUpdate
  selector:
    matchLabels:
      app: calorie-tracker-hasura
  template:
    metadata:
      labels:
        app: calorie-tracker-hasura
    spec:
      restartPolicy: Always
      imagePullSecrets:
      - name: regcred
      containers:
      - image: hasura_container_img_placeholder
        imagePullPolicy: IfNotPresent
        name: hasura
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080
          initialDelaySeconds: 60
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /healthz
            port: 8080
          initialDelaySeconds: 60
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        env:
        - name: HASURA_GRAPHQL_CORS_DOMAIN
          value: "https://domain_name_placeholder"
        - name: HASURA_GRAPHQL_DEV_MODE
          value: "true"
        - name: HASURA_GRAPHQL_ENABLE_CONSOLE
          value: "true"
        - name: HASURA_GRAPHQL_ENABLED_LOG_TYPES
          value: "startup, http-log, webhook-log, websocket-log, query-log"
        - name: PG_DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: calorie-tracker
              key: PG_DATABASE_URL
        - name: HASURA_GRAPHQL_DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: calorie-tracker
              key: HASURA_GRAPHQL_DATABASE_URL
        - name: HASURA_GRAPHQL_METADATA_DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: calorie-tracker
              key: HASURA_GRAPHQL_METADATA_DATABASE_URL
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: calorie-tracker
              key: POSTGRES_PASSWORD
        - name: HASURA_GRAPHQL_ADMIN_SECRET
          valueFrom:
            secretKeyRef:
              name: calorie-tracker
              key: HASURA_GRAPHQL_ADMIN_SECRET
        - name: HASURA_GRAPHQL_JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: calorie-tracker
              key: HASURA_GRAPHQL_JWT_SECRET
        ports:
        - containerPort: 8080
          name: hasura
          protocol: TCP
---
apiVersion: v1
kind: Service
metadata:
  name: hasura-service
  namespace: calorie-tracker
spec:
  selector:
    app: calorie-tracker-hasura
  type: ClusterIP
  ports:
  - name: hasura-port
    port: 8080
    targetPort: 8080
    protocol: TCP
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres-deployment
  namespace: calorie-tracker
  labels:
    app: calorie-tracker-postgres
spec:
  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
    type: RollingUpdate
  selector:
    matchLabels:
      app: calorie-tracker-postgres
  template:
    metadata:
      labels:
        app: calorie-tracker-postgres
    spec:
      restartPolicy: Always
      volumes:
      - name: db
        persistentVolumeClaim:
          claimName: calorie-tracker-postgres
      - name: init
        configMap:
          name: calorie-tracker-postgres-init
      containers:
      - image: postgres:15
        imagePullPolicy: Always
        name: postgres
        env:
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: calorie-tracker
              key: POSTGRES_PASSWORD
        volumeMounts:
        - mountPath: /var/lib/postgresql
          name: db
        - name: init
          mountPath: /docker-entrypoint-initdb.d/init.sql
          subPath: init
        livenessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - pg_isready -U postgres
          initialDelaySeconds: 60
          periodSeconds: 10
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 5
        readinessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - pg_isready -U postgres
          initialDelaySeconds: 60
          periodSeconds: 10
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 5
        ports:
        - containerPort: 5432
          name: postgres
          protocol: TCP
---
apiVersion: v1
kind: Service
metadata:
  name: postgres-service
  namespace: calorie-tracker
spec:
  selector:
    app: calorie-tracker-postgres
  type: ClusterIP
  ports:
  - name: postgres-port
    port: 5432
    targetPort: 5432
    protocol: TCP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: calorie-tracker
  namespace: calorie-tracker
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
    #nginx.ingress.kubernetes.io/add-response-header: "Referrer-Policy=strict-origin,Strict-Transport-Security 'max-age=31536000; includeSubDomains;',X-Content-Type-Options=nosniff,X-Frame-Options=DENY,X-XSS-Protection='1; mode=block'"
    # TODO Fix response headers not getting attached
    nginx.ingress.kubernetes.io/add-response-header: "Referrer-Policy=strict-origin,Strict-Transport-Security 'max-age=31536000; includeSubDomains;',X-Content-Type-Options=nosniff,X-Frame-Options=DENY,X-XSS-Protection='1; mode=block',Permissions-Policy='accelerometer=(self), autoplay=(self), camera=(self), cross-origin-isolated=(self), display-capture=(self), encrypted-media=(self), fullscreen=(self), geolocation=(self), gyroscope=(self), keyboard-map=(self), magnetometer=(self), microphone=(self), midi=(self), payment=(self), picture-in-picture=(self), publickey-credentials-get=(self), screen-wake-lock=(self), sync-xhr=(self), usb=(self), xr-spatial-tracking=(self)'"
    external-dns.alpha.kubernetes.io/target: "k8s.schittko.me"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  rules:
  - host: domain_name_placeholder
    http:
      paths:
      - backend:
          service:
            name: "hasura-service"
            port:
              number: 8080
        path: "/v1"
        pathType: Prefix
      - backend:
          service:
            name: "hasura-service"
            port:
              number: 8080
        path: "/v2"
        pathType: Prefix
      - backend:
          service:
            name: "hasura-service"
            port:
              number: 8080
        path: "/console"
        pathType: Prefix
      - backend:
          service:
            name: "hasura-service"
            port:
              number: 8080
        path: "/healthz"
        pathType: Prefix
      - backend:
          service:
            name: "client-service"
            port:
              number: 3000
        path: "/"
        pathType: ImplementationSpecific
  tls:
  - hosts:
    - domain_name_placeholder
    secretName: domain_name_placeholder
