const Stripe = require('stripe');

exports.handler = async (event) => {
  const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Content-Type': 'application/json',
  };

  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 204, headers, body: '' };
  }
  if (event.httpMethod !== 'POST') {
    return { statusCode: 405, headers, body: JSON.stringify({ error: 'Method not allowed' }) };
  }

  const stripe = Stripe(process.env.STRIPE_SECRET_KEY);
  const { plan, email, userId, annual } = JSON.parse(event.body);

  const PRICES = {
    starter: process.env.STRIPE_PRICE_STARTER,
    pro: process.env.STRIPE_PRICE_PRO,
    elite: process.env.STRIPE_PRICE_ELITE,
  };

  const priceId = PRICES[plan];
  if (!priceId) {
    return { statusCode: 400, headers, body: JSON.stringify({ error: 'Plan no válido' }) };
  }

  try {
    const sessionParams = {
      mode: 'subscription',
      payment_method_types: ['card'],
      line_items: [{ price: priceId, quantity: 1 }],
      success_url: `${event.headers.origin || event.headers.referer?.replace(/\/[^/]*$/, '')}?checkout=success&plan=${plan}&session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${event.headers.origin || event.headers.referer?.replace(/\/[^/]*$/, '')}?checkout=canceled`,
      metadata: { userId: userId || '', plan },
      allow_promotion_codes: true,
      billing_address_collection: 'auto',
      locale: 'es',
    };

    if (email) sessionParams.customer_email = email;

    if (annual) {
      sessionParams.subscription_data = {
        metadata: { plan, userId: userId || '' },
      };
    }

    const session = await stripe.checkout.sessions.create(sessionParams);

    return {
      statusCode: 200,
      headers,
      body: JSON.stringify({ url: session.url, sessionId: session.id }),
    };
  } catch (err) {
    console.error('Stripe error:', err.message);
    return {
      statusCode: 500,
      headers,
      body: JSON.stringify({ error: 'Error al crear la sesión de pago' }),
    };
  }
};
